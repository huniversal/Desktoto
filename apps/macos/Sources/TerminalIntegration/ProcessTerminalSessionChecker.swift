import Boundaries
import Domain
import Foundation
import Synchronization

/// 터미널 세션의 프로세스가 살아 있는지로 세션이 닫혔는지 판단한다.
/// Claude는 실행 중인 프로세스마다 `~/.claude/sessions/<pid>.json`을 남기고 끝나면 지운다.
/// Codex는 기록 파일을 터미널 프로세스가 아니라 뒤에서 도는 서버가 열고 있어서, 같은 작업 폴더의 터미널 `codex` 프로세스가 있는지로 본다.
public final class ProcessTerminalSessionChecker: TerminalSessionChecker {
    private static let claudeRefreshInterval: TimeInterval = 1
    private static let codexRefreshInterval: TimeInterval = 5

    private struct Cache {
        var claudeLiveSessionIDs: (checkedAt: Date, ids: Set<String>?)?
        var codexLiveDirectories: (checkedAt: Date, directories: [String?])?
    }

    private let fileSystem: any FileSystem
    private let processRunner: any ProcessRunner
    private let timeSource: any TimeSource
    private let cache = Mutex(Cache())

    public init(fileSystem: any FileSystem, processRunner: any ProcessRunner, timeSource: any TimeSource) {
        self.fileSystem = fileSystem
        self.processRunner = processRunner
        self.timeSource = timeSource
    }

    public func isClosed(sessionID: String, tool: AiTool, workingDirectory: String?) -> Bool {
        let now = timeSource.now
        switch tool {
        case .claude:
            // 폴더가 없는 예전 버전이면 판단할 수 없으므로 닫혔다고 보지 않는다.
            guard let liveIDs = liveClaudeSessionIDs(now: now) else { return false }
            return !liveIDs.contains(sessionID)
        case .codex:
            guard let workingDirectory else { return false }
            let target = TerminalProcessMatcher.normalizePath(workingDirectory)
            // 작업 폴더를 읽지 못한 프로세스가 있으면 판단할 수 없으므로 닫혔다고 보지 않는다.
            return !liveCodexDirectories(now: now).contains { $0 == nil || $0 == target }
        }
    }

    // MARK: - Claude

    /// 살아 있는 프로세스의 세션 id들. 폴더가 없으면 nil이다.
    private func liveClaudeSessionIDs(now: Date) -> Set<String>? {
        if let cached = cache.withLock({ $0.claudeLiveSessionIDs }),
           now.timeIntervalSince(cached.checkedAt) < Self.claudeRefreshInterval {
            return cached.ids
        }
        let directory = fileSystem.homeDirectory.appendingPathComponent(".claude/sessions")
        var ids: Set<String>?
        if fileSystem.directoryExists(at: directory) {
            ids = Set(fileSystem.listFiles(under: directory, withExtension: "json").compactMap { entry -> String? in
                guard let data = fileSystem.readAll(of: entry.url),
                      let json = JSONValue.parseObject(from: data),
                      let sessionID = json["sessionId"]?.stringValue,
                      let pid = json["pid"]?.intValue,
                      processRunner.isProcessAlive(pid: pid) else { return nil }
                return sessionID
            })
        }
        cache.withLock { $0.claudeLiveSessionIDs = (now, ids) }
        return ids
    }

    // MARK: - Codex

    /// 터미널에서 도는 codex 프로세스들의 작업 폴더. 읽지 못한 프로세스는 nil이다.
    private func liveCodexDirectories(now: Date) -> [String?] {
        if let cached = cache.withLock({ $0.codexLiveDirectories }),
           now.timeIntervalSince(cached.checkedAt) < Self.codexRefreshInterval {
            return cached.directories
        }
        let directories = TerminalProcessScanner(processRunner: processRunner)
            .listProcesses(commandNames: [TerminalProcessMatcher.commandName(for: .codex)], now: now)
            .map { $0.workingDirectory.map(TerminalProcessMatcher.normalizePath) }
        cache.withLock { $0.codexLiveDirectories = (now, directories) }
        return directories
    }
}
