import Boundaries
import Domain
import Foundation

/// Claude Code(`~/.claude/projects`)와 Codex(`~/.codex/sessions`)의 기록 파일을 감시해
/// 세션이 작업 중인지 판정하고, 세션별 모델과 컨텍스트 사용량을 읽는다.
/// 터미널 프로세스가 살아 있는지는 직접 확인하지 않고, 주입받은 `TerminalSessionChecker`에 묻는다.
public actor SessionMonitor {
    private struct CachedActivity {
        let modifiedAt: Date
        let snapshot: ActivitySnapshot
    }

    private struct CachedWaiting {
        let modifiedAt: Date
        let kind: WaitingKind?
    }

    private let fileSystem: any FileSystem
    private let timeSource: any TimeSource
    private let recordReader: LogRecordReader
    private let waitingSignalReader: WaitingSignalReader
    private let originReader: CodexOriginReader
    private let infoReader: SessionInfoReader
    private let terminalSessionChecker: (any TerminalSessionChecker)?
    private let sessionLinkResolver: (any SessionLinkResolver)?

    /// 수정 시각이 같으면 이전 결과를 다시 쓴다. 1초마다 호출되어도 기록 파일은 바뀔 때만 읽는다.
    private var activityCache: [String: CachedActivity] = [:]
    /// 기록으로 판정한 질문 대기. 기록 파일이 바뀔 때만 다시 계산하도록 수정 시각과 함께 저장한다.
    private var logWaitingCache: [String: CachedWaiting] = [:]
    /// 첫 줄은 바뀌지 않으므로 경로별로 한 번만 읽는다.
    private var codexOriginCache: [String: CodexOrigin] = [:]
    /// Claude 기록이 터미널 세션의 것인지. 기록을 읽지 못한 경우는 저장하지 않는다.
    private var claudeTerminalCache: [String: Bool] = [:]
    private var recentFiles: [String: LogFile] = [:]

    public init(
        fileSystem: any FileSystem,
        timeSource: any TimeSource,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        terminalSessionChecker: (any TerminalSessionChecker)? = nil,
        sessionLinkResolver: (any SessionLinkResolver)? = nil
    ) {
        self.fileSystem = fileSystem
        self.timeSource = timeSource
        self.terminalSessionChecker = terminalSessionChecker
        self.sessionLinkResolver = sessionLinkResolver
        recordReader = LogRecordReader(fileSystem: fileSystem)
        waitingSignalReader = WaitingSignalReader(fileSystem: fileSystem)
        originReader = CodexOriginReader(fileSystem: fileSystem)
        infoReader = SessionInfoReader(
            windowResolver: ContextWindowResolver(fileSystem: fileSystem, environment: environment)
        )
    }

    // MARK: - 공개 조회

    /// 최근 활동한 세션의 진행 상태를 id별로 돌려준다. 가볍게 자주 호출할 수 있다.
    public func sessionStates() -> [String: SessionRunState] {
        let now = timeSource.now
        let files = recentLogFiles(now: now)
        recentFiles = Dictionary(files.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return recentFiles.mapValues { RunStateJudge.runState(for: $0, now: now) }
    }

    /// 마지막 sessionStates()에서 본 세션의 상세 정보를 읽는다.
    public func sessionInfo(id: String) -> SessionInfo? {
        guard let file = recentFiles[id] else { return nil }
        return makeSessionInfo(file: file, now: timeSource.now)
    }

    /// 최근 활동한 세션을 최신순으로 돌려준다.
    public func activeSessions() -> [SessionInfo] {
        let now = timeSource.now
        return recentLogFiles(now: now)
            .sorted { $0.activity > $1.activity }
            .prefix(SessionMonitoringPolicy.maxSessionCount)
            .map { makeSessionInfo(file: $0, now: now) }
    }

    /// 응답을 기다리는 세션과 그 이유. 마지막 sessionStates()에서 본 최근 세션만 대상으로 한다.
    public func waitingKinds() -> [String: WaitingKind] {
        let now = timeSource.now
        return recentFiles.values.reduce(into: [:]) { result, file in
            if let kind = waitingKind(for: file, now: now) { result[file.id] = kind }
        }
    }

    // MARK: - 파일 탐색

    /// 최근 activeWindow 안에 수정되고, 기록 안의 마지막 실제 활동도 그 안에 있는 .jsonl 파일만 대상으로 삼는다.
    private func recentLogFiles(now: Date) -> [LogFile] {
        let roots: [(URL, AiTool)] = [
            (fileSystem.homeDirectory.appendingPathComponent(".claude/projects"), .claude),
            (fileSystem.homeDirectory.appendingPathComponent(".codex/sessions"), .codex)
        ]
        var files: [LogFile] = []
        var seenPaths: Set<String> = []
        for (root, tool) in roots {
            for entry in fileSystem.listFiles(under: root, withExtension: "jsonl")
            where now.timeIntervalSince(entry.modifiedAt) < SessionMonitoringPolicy.activeWindow {
                seenPaths.insert(entry.url.path)
                let snapshot = activitySnapshot(of: entry, tool: tool)
                guard now.timeIntervalSince(snapshot.lastActivity) < SessionMonitoringPolicy.activeWindow else { continue }
                let file = LogFile(
                    url: entry.url,
                    modifiedAt: entry.modifiedAt,
                    tool: tool,
                    activity: snapshot.lastActivity,
                    outcome: snapshot.outcome
                )
                guard !isClosedTerminalSession(file) else { continue }
                files.append(file)
            }
        }
        activityCache = activityCache.filter { seenPaths.contains($0.key) }
        claudeTerminalCache = claudeTerminalCache.filter { seenPaths.contains($0.key) }
        let currentIDs = Set(files.map(\.id))
        logWaitingCache = logWaitingCache.filter { currentIDs.contains($0.key) }
        return files
    }

    // MARK: - 터미널 세션 생존

    /// 터미널에서 시작한 세션이고 그 프로세스가 끝났으면 true. 터미널 세션이 아니거나 판단할 수 없으면 false다.
    private func isClosedTerminalSession(_ file: LogFile) -> Bool {
        guard let terminalSessionChecker else { return false }
        switch file.tool {
        case .claude:
            guard isClaudeTerminalLog(file) else { return false }
            return terminalSessionChecker.isClosed(sessionID: file.id, tool: .claude, workingDirectory: nil)
        case .codex:
            let origin = codexOrigin(of: file.url)
            guard origin.isTerminalSession else { return false }
            return terminalSessionChecker.isClosed(sessionID: file.id, tool: .codex, workingDirectory: origin.workingDirectory)
        }
    }

    /// 기록에 entrypoint가 cli인 줄이 있으면 터미널 세션이다. 첫 읽기 범위 안에서만 찾는다(원본과 같다).
    private func isClaudeTerminalLog(_ file: LogFile) -> Bool {
        if let cached = claudeTerminalCache[file.url.path] { return cached }
        let records = recordReader.records(
            at: file.url,
            tool: .claude,
            claudeTypes: SessionMonitoringPolicy.claudeInfoTypes,
            steps: [SessionMonitoringPolicy.infoTailByteSteps[0]],
            isSufficient: { _ in true }
        )
        guard !records.isEmpty else { return false }
        let isTerminal = records.contains { $0["entrypoint"]?.stringValue == "cli" }
        claudeTerminalCache[file.url.path] = isTerminal
        return isTerminal
    }

    // MARK: - 활동 판정

    private func activitySnapshot(of entry: FileEntry, tool: AiTool) -> ActivitySnapshot {
        if let cached = activityCache[entry.url.path], cached.modifiedAt == entry.modifiedAt { return cached.snapshot }
        let records = recordReader.records(
            at: entry.url,
            tool: tool,
            claudeTypes: SessionMonitoringPolicy.claudeActivityTypes,
            steps: SessionMonitoringPolicy.stateTailByteSteps,
            isSufficient: { ActivityJudge.snapshot(records: $0, tool: tool, modifiedAt: entry.modifiedAt) != nil }
        )
        let snapshot = ActivityJudge.snapshot(records: records, tool: tool, modifiedAt: entry.modifiedAt)
            ?? ActivitySnapshot(lastActivity: entry.modifiedAt, outcome: .stopped)
        activityCache[entry.url.path] = CachedActivity(modifiedAt: entry.modifiedAt, snapshot: snapshot)
        return snapshot
    }

    // MARK: - 사람의 응답 대기 (승인, 질문)

    /// hook이 알려준 승인 대기가 우선이고, 없으면 기록에서 질문 대기를 찾는다.
    private func waitingKind(for file: LogFile, now: Date) -> WaitingKind? {
        let isWaitingByHook = waitingSignalReader.isWaiting(sessionID: file.id, now: now) {
            recordReader.lastConversationRecord(of: file).flatMap { RecordTimestamp.date(of: $0) }
        }
        return isWaitingByHook ? .approval : logWaitingKind(for: file)
    }

    private func logWaitingKind(for file: LogFile) -> WaitingKind? {
        if let cached = logWaitingCache[file.id], cached.modifiedAt == file.modifiedAt { return cached.kind }
        let kind = computeLogWaitingKind(for: file)
        logWaitingCache[file.id] = CachedWaiting(modifiedAt: file.modifiedAt, kind: kind)
        return kind
    }

    /// Codex는 기록 기반 대기 판정을 하지 않는다.
    private func computeLogWaitingKind(for file: LogFile) -> WaitingKind? {
        guard file.tool == .claude, let lastRecord = recordReader.lastConversationRecord(of: file) else { return nil }
        return WaitingJudge.waitingKind(
            lastConversation: lastRecord,
            infoRecords: { recordReader.infoRecords(of: file) }
        )
    }

    // MARK: - 세션 정보

    private func makeSessionInfo(file: LogFile, now: Date) -> SessionInfo {
        let records = recordReader.infoRecords(of: file)
        let waitingKind = waitingKind(for: file, now: now)
        let isRunning = waitingKind == nil && RunStateJudge.runState(for: file, now: now) == .running
        // 기록 파일이 만들어진 시각을 세션이 시작된 시각으로 본다. 어느 터미널 프로세스의 세션인지 맞출 때 쓴다.
        let startedAt = fileSystem.creationDate(of: file.url)
        switch file.tool {
        case .claude:
            return infoReader.claudeInfo(
                records: records,
                file: file,
                startedAt: startedAt,
                isRunning: isRunning,
                waitingKind: waitingKind,
                openURL: sessionLinkResolver?.url(forSessionID: file.id)
            )
        case .codex:
            return infoReader.codexInfo(
                records: records,
                file: file,
                origin: codexOrigin(of: file.url),
                startedAt: startedAt,
                isRunning: isRunning,
                waitingKind: waitingKind
            )
        }
    }

    private func codexOrigin(of url: URL) -> CodexOrigin {
        if let cached = codexOriginCache[url.path] { return cached }
        guard let origin = originReader.origin(of: url) else { return .unknown }
        codexOriginCache[url.path] = origin
        return origin
    }
}
