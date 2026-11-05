import Boundaries
import Domain
import Foundation
import TestSupport
import Testing
@testable import UsageMonitoring

struct UsageTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    func json(_ text: String) throws -> JSONValue {
        try #require(JSONValue.parseObject(from: Data(text.utf8)))
    }

    @Test func resetAndStalenessBoundaries() {
        let usage = ToolUsage(tool: .claude, fiveHour: UsageWindow(usedRatio: 0.8, resetsAt: now), weekly: nil, updatedAt: now)
        #expect(usage.resetAware(at: now).fiveHour == UsageWindow(usedRatio: 0, resetsAt: nil))
        #expect(usage.createStaleText(now: now.addingTimeInterval(599)) == nil)
        #expect(usage.createStaleText(now: now.addingTimeInterval(600)) == "10분 전 기준")
        #expect(usage.createStaleText(now: now.addingTimeInterval(3600)) == "1시간 전 기준")
        #expect(usage.createStaleText(now: now.addingTimeInterval(86400)) == "1일 전 기준")
        #expect(usage.fiveHour?.usedRatio == 0.8)
    }

    @Test func parsersPreserveSourceContracts() throws {
        let desktop = try json(#"{"five_hour":{"utilization":120,"resets_at":"2033-05-18T03:33:20.123456Z"},"seven_day":{"utilization":-1}}"#)
        let parsed = try #require(UsageParser.claude(desktop, desktop: true, updatedAt: now))
        #expect(parsed.fiveHour?.usedRatio == 1)
        #expect(parsed.weekly?.usedRatio == 0)
        #expect(parsed.fiveHour?.resetsAt == now)
        #expect(UsageParser.parseDate("broken") == nil)
        let limits = try json(#"{"primary":{"used_percent":20,"window_minutes":600},"secondary":{"used_percent":40,"window_minutes":7200}}"#)
        #expect(UsageParser.codex(limits, live: false, updatedAt: nil)?.fiveHour?.usedRatio == 0.2)
        #expect(UsageParser.codex(limits, live: false, updatedAt: nil)?.weekly?.usedRatio == 0.4)
        let ignored = try json(#"{"primary":{"usedPercent":20,"windowDurationMins":601}}"#)
        #expect(UsageParser.codex(ignored, live: true, updatedAt: now) == nil)
    }

    @Test func completeLinesRetainPartialUTF8() {
        var bytes = Data("\n{\"a\":1}\n한".utf8)
        #expect(UsageParser.takeCompleteLines(from: &bytes) == [Data(#"{"a":1}"#.utf8)])
        #expect(bytes == Data("한".utf8))
        bytes.append(contentsOf: "글\n".utf8)
        #expect(UsageParser.takeCompleteLines(from: &bytes) == [Data("한글".utf8)])
    }

    func entry(body: Data, key keyText: String = "https://claude.ai/api/organizations/abcd-1234/usage") -> Data {
        let key = Data(keyText.utf8)
        var bytes = Data(repeating: 0, count: 24)
        let magic: UInt64 = 0xfcfb6d1ba7725c30
        for index in 0..<8 { bytes[index] = UInt8(truncatingIfNeeded: magic >> (index * 8)) }
        for index in 0..<4 { bytes[12 + index] = UInt8(truncatingIfNeeded: key.count >> (index * 8)) }
        bytes.append(key)
        bytes.append(body)
        return bytes
    }

    @Test func usageKeyAcceptsQueryVariantsOnly() {
        let base = "https://claude.ai/api/organizations/0b004cf6-ca71-4332-98cd-4d7bce2d1b2e/usage"
        #expect(ClaudeCacheParser.isUsageKey(base))
        #expect(ClaudeCacheParser.isUsageKey("\(base)?skip_spend=1"))
        #expect(ClaudeCacheParser.isUsageKey("\(base)?cedar_ember=1&skip_spend=1"))
        #expect(ClaudeCacheParser.isUsageKey("\(base)/other") == false)
        #expect(ClaudeCacheParser.isUsageKey("\(base)s") == false)
        #expect(ClaudeCacheParser.isUsageKey("https://claude.ai/api/organizations/not-hex-zz/usage?skip_spend=1") == false)
        #expect(ClaudeCacheParser.isUsageKey("https://claude.ai/api/organizations/abcd-1234/overage?usage") == false)
    }

    @Test func cacheHeaderAndCompressedFrame() throws {
        let body = Data(#"{"five_hour":{"utilization":50}}"#.utf8)
        let bytes = entry(body: body)
        #expect(ClaudeCacheParser.parse(bytes, modifiedAt: now)?.fiveHour?.usedRatio == 0.5)
        #expect(ClaudeCacheParser.key(in: bytes.prefix(20)) == nil)
        #expect(ClaudeCacheParser.isUsageKey("/api/organizations/xyz/usage") == false)
        // 단일 raw block으로 이루어진 합성 zstd 프레임.
        var frame = Data([0x28, 0xb5, 0x2f, 0xfd, 0x20, UInt8(body.count)])
        let block = body.count << 3 | 1
        frame.append(contentsOf: (0..<3).map { UInt8(truncatingIfNeeded: block >> ($0 * 8)) })
        frame.append(body)
        #expect(ClaudeCacheParser.decompress(frame) == body)
        #expect(ClaudeCacheParser.decompress(Data(frame.dropLast())) == nil)
        frame.append(contentsOf: [1, 2, 3])
        #expect(ClaudeCacheParser.parse(entry(body: frame), modifiedAt: now)?.fiveHour?.usedRatio == 0.5)
    }

    @Test func fileFallbackCacheAndResetOnEveryRead() async throws {
        let files = InMemoryFileSystem()
        let time = FixedTimeSource(now: now)
        let status = files.homeDirectory.appendingPathComponent(".ai-run/status/a.json")
        files.addFile(at: status, text: #"{"rate_limits":{"five_hour":{"used_percentage":30}}}"#, modifiedAt: now)
        let rollout = files.homeDirectory.appendingPathComponent(".codex/sessions/a.jsonl")
        files.addFile(at: rollout, text: #"{"timestamp":"2033-05-18T03:33:20Z","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":80,"window_minutes":300,"resets_at":2000000001}}}}"#, modifiedAt: now)
        let live = CodexRateLimitReader(fileSystem: files, timeSource: time)
        let monitor = UsageMonitor(fileSystem: files, timeSource: time, codexReader: live)
        let first = await monitor.getUsages()
        #expect(first.map(\.tool) == [.claude, .codex])
        #expect(first.last?.fiveHour?.usedRatio == 0.8)
        let reads = files.readCount(of: rollout)
        time.advance(by: 1)
        let second = await monitor.getUsages()
        #expect(second.last?.fiveHour?.usedRatio == 0)
        #expect(files.readCount(of: rollout) == reads)
        await monitor.stop()
    }

    @Test func rpcHandshakeReuseAndFailureKeepsLastValue() async throws {
        let files = InMemoryFileSystem()
        files.addFile(at: files.homeDirectory.appendingPathComponent(".local/bin/codex"), text: "", modifiedAt: now)
        let launcher = ScriptedProcessLauncher { data in
            guard let message = JSONValue.parseObject(from: data), let id = message["id"]?.intValue else { return [] }
            let result = message["method"]?.stringValue == "initialize" ? "{}" : #"{"rateLimits":{"primary":{"usedPercent":42,"windowDurationMins":300}}}"#
            let line = Data("{\"id\":\(id),\"result\":\(result)}\n".utf8)
            return [Data(line.prefix(5)), Data(line.dropFirst(5))]
        }
        let reader = CodexRateLimitReader(fileSystem: files, launcher: launcher, timeSource: FixedTimeSource(now: now))
        await reader.refresh(minInterval: 0)
        #expect(await reader.latest?.fiveHour?.usedRatio == 0.42)
        await reader.refresh(minInterval: 30)
        #expect(launcher.writes.count == 3)
        await reader.refresh(minInterval: 0)
        #expect(launcher.writes.count == 4)
        #expect(launcher.launchCount == 1)
        await reader.setEnabled(false)
        #expect(launcher.terminationCount == 1)
        #expect(await reader.latest?.fiveHour?.usedRatio == 0.42)
        await reader.refresh(minInterval: 0)
        #expect(launcher.launchCount == 1)
    }
    @Test(arguments: [(40, 1), (41, 0)])
    func onlyFortyNewestStatusFilesAreCandidates(fileCount: Int, expectedUsages: Int) async {
        let files = InMemoryFileSystem()
        for index in 0..<fileCount {
            let url = files.homeDirectory.appendingPathComponent(".ai-run/status/\(index).json")
            let text = index == 0 ? #"{"rate_limits":{"five_hour":{"used_percentage":50}}}"# : "broken"
            files.addFile(at: url, text: text, modifiedAt: now.addingTimeInterval(Double(index)))
        }
        let monitor = UsageMonitor(fileSystem: files, timeSource: FixedTimeSource(now: now))
        #expect(await monitor.getUsages().count == expectedUsages)
        await monitor.stop()
    }

    @Test func malformedSecondaryDoesNotEraseLivePrimary() throws {
        let limits = try json(#"{"primary":{"usedPercent":25,"windowDurationMins":300},"secondary":{"windowDurationMins":300}}"#)
        #expect(UsageParser.codex(limits, live: true, updatedAt: now)?.fiveHour?.usedRatio == 0.25)
    }

    @Test func liveFileMetadataUsesImmediateVisibleChildren() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("visible_0")
        try Data([1, 2, 3]).write(to: file)
        try Data([1]).write(to: root.appendingPathComponent(".hidden_0"))
        try Data([1]).write(to: root.appendingPathComponent("nested/child_0"))
        let files = LiveFileSystem(homeDirectory: root)
        #expect(files.fileSize(at: file) == 3)
        #expect(Set(files.listDirectory(at: root).map { $0.url.lastPathComponent }) == ["visible_0", "nested"])
        #expect(files.isExecutable(at: file) == false)
        #expect(files.isExecutable(at: URL(fileURLWithPath: "/bin/cat")))
    }

}
