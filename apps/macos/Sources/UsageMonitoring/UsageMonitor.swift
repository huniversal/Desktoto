import Boundaries
import Domain
import Foundation

/// 파일 캐시와 탐색 작업은 이 actor가 소유한다. 앱은 UI 주기에 맞춰 조회한다.
public actor UsageMonitor {
    private let files: any FileSystem
    private let time: any TimeSource
    private let live: CodexRateLimitReader
    private var entries: [URL] = []
    private var discovery: Task<[URL], Never>?
    private var discoveryGeneration = 0
    private var lastDiscovery = Date.distantPast
    private var desktopCaches: [URL: (modified: Date, usage: ToolUsage?)] = [:]
    private var rolloutCache: [URL: (modified: Date, usage: ToolUsage?)] = [:]

    public init(fileSystem: any FileSystem = LiveFileSystem(), timeSource: any TimeSource = SystemTimeSource(), codexReader: CodexRateLimitReader? = nil) {
        files = fileSystem
        time = timeSource
        live = codexReader ?? CodexRateLimitReader(fileSystem: fileSystem, timeSource: timeSource)
    }

    public func refreshCodexLive(minInterval: TimeInterval) async { await live.refresh(minInterval: minInterval) }
    public func setCodexLiveEnabled(_ enabled: Bool) async { await live.setEnabled(enabled) }
    public func stop() async {
        discoveryGeneration += 1
        discovery?.cancel()
        discovery = nil
        await live.stop()
    }

    public func getUsages() async -> [ToolUsage] {
        let now = time.now
        let claude = newest([desktop(now: now), statusLine()])
        let codex = newest([await live.latest, rollout()])
        return [claude, codex].compactMap { $0?.resetAware(at: now) }
    }

    private func newest(_ candidates: [ToolUsage?]) -> ToolUsage? {
        candidates.compactMap { $0 }.max { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
    }

    private func newestFiles(_ path: String, extension suffix: String) -> [FileEntry] {
        Array(files.listFiles(under: files.homeDirectory.appendingPathComponent(path), withExtension: suffix)
            .sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5))
    }

    private func statusLine() -> ToolUsage? {
        for file in newestFiles(".ai-run/status", extension: "json") {
            guard let bytes = files.readAll(of: file.url), let json = JSONValue.parseObject(from: bytes),
                  let limits = json["rate_limits"], let usage = UsageParser.claude(limits, desktop: false, updatedAt: file.modifiedAt) else { continue }
            return usage
        }
        return nil
    }

    private func rollout() -> ToolUsage? {
        var visited: Set<URL> = []
        defer { rolloutCache = rolloutCache.filter { visited.contains($0.key) } }
        for file in newestFiles(".codex/sessions", extension: "jsonl") {
            visited.insert(file.url)
            if rolloutCache[file.url]?.modified != file.modifiedAt {
                rolloutCache[file.url] = (file.modifiedAt, readRollout(file.url))
            }
            if let usage = rolloutCache[file.url]?.usage { return usage }
        }
        return nil
    }

    private func readRollout(_ url: URL) -> ToolUsage? {
        for size: UInt64 in [65_536, 524_288, 4_194_304] {
            for record in LogTail.readRecords(of: url, maxBytes: size, fileSystem: files).records {
                guard let payload = record["payload"], payload["type"]?.stringValue == "token_count", let limits = payload["rate_limits"] else { continue }
                if let usage = UsageParser.codex(limits, live: false, updatedAt: record["timestamp"]?.stringValue.flatMap(UsageParser.parseDate)) { return usage }
            }
        }
        return nil
    }

    private func desktop(now: Date) -> ToolUsage? {
        entries = entries.filter { files.modificationDate(of: $0) != nil }
        desktopCaches = desktopCaches.filter { entries.contains($0.key) }
        startDiscoveryIfDue(now: now)
        for url in entries {
            guard let modified = files.modificationDate(of: url) else { continue }
            if desktopCaches[url]?.modified != modified {
                let usage = files.readAll(of: url).flatMap { ClaudeCacheParser.parse($0, modifiedAt: modified) }
                desktopCaches[url] = (modified, usage)
            }
        }
        return newest(entries.map { desktopCaches[$0]?.usage })
    }

    private func startDiscoveryIfDue(now: Date) {
        guard discovery == nil, now.timeIntervalSince(lastDiscovery) >= 120 else { return }
        lastDiscovery = now
        discoveryGeneration += 1
        let current = discoveryGeneration
        let files = files
        let task = Task.detached { Self.findEntries(files: files) }
        discovery = task
        Task { [weak self] in
            let found = await task.value
            await self?.completeDiscovery(found, generation: current)
        }
    }

    private func completeDiscovery(_ found: [URL], generation: Int) {
        guard generation == discoveryGeneration, discovery != nil else { return }
        entries = found
        discovery = nil
    }

    private nonisolated static func findEntries(files: any FileSystem) -> [URL] {
        let directory = files.homeDirectory.appendingPathComponent("Library/Application Support/Claude/Cache/Cache_Data")
        let candidates = files.listDirectory(at: directory).filter {
            guard $0.url.lastPathComponent.hasSuffix("_0"), let size = files.fileSize(at: $0.url) else { return false }
            return (500...65_536).contains(size)
        }.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(600)
        return candidates.filter {
            guard let head = files.readHead(of: $0.url, maxBytes: 536), let key = ClaudeCacheParser.key(in: head) else { return false }
            return ClaudeCacheParser.isUsageKey(key)
        }.map(\.url)
    }
}
