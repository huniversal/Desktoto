import Boundaries
import Domain
import Foundation

/// Claude Code(`~/.claude/projects`)와 Codex(`~/.codex/sessions`)의 기록 파일을 감시해
/// 세션이 작업 중인지 판정하고, 세션별 모델과 컨텍스트 사용량을 읽는다.
/// Antigravity App(`~/.gemini/antigravity`)은 기록 파일이 아니라 SQLite의 상태로 판정한다.
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
    private let antigravityReader: AntigravityReader
    /// Antigravity.app을 찾는 폴더들. 설치 위치가 /Applications 아니면 ~/Applications다.
    private let applicationDirectories: [URL]

    /// 수정 시각이 같으면 이전 결과를 다시 쓴다. 1초마다 호출되어도 기록 파일은 바뀔 때만 읽는다.
    private var activityCache: [String: CachedActivity] = [:]
    /// 기록으로 판정한 질문 대기. 기록 파일이 바뀔 때만 다시 계산하도록 수정 시각과 함께 저장한다.
    private var logWaitingCache: [String: CachedWaiting] = [:]
    /// 첫 줄은 바뀌지 않으므로 경로별로 한 번만 읽는다.
    private var codexOriginCache: [String: CodexOrigin] = [:]
    /// Claude 기록이 터미널 세션의 것인지. 기록을 읽지 못한 경우는 저장하지 않는다.
    private var claudeTerminalCache: [String: Bool] = [:]
    private var recentFiles: [String: LogFile] = [:]
    /// Codex 제목 목록. 파일의 수정 시각이 바뀔 때만 다시 읽는다.
    private var codexTitleCache: (modifiedAt: Date, titles: [String: String])?
    /// 마지막 조회에서 본 최근 Antigravity 대화와 그중 승인을 기다리는 대화.
    private var recentAntigravity: [String: AntigravityConversation] = [:]
    private var antigravityWaitingIDs: Set<String> = []
    /// SQLite 파일은 WAL 때문에 본 파일의 수정 시각이 바로 바뀌지 않아서 -wal 파일의 시각까지 함께 비교한다.
    private var antigravitySummaryCache: (signature: [Date?], conversations: [AntigravityConversation])?
    private var antigravityStepsCache: [String: (signature: [Date?], isWaiting: Bool, modelName: String?)] = [:]
    private var antigravityTokensCache: [String: (signature: [Date?], usedTokens: Int?)] = [:]
    private var antigravityModelNames: [String: String] = [:]
    private var antigravityUsedTokens: [String: Int] = [:]

    public init(
        fileSystem: any FileSystem,
        timeSource: any TimeSource,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        terminalSessionChecker: (any TerminalSessionChecker)? = nil,
        sessionLinkResolver: (any SessionLinkResolver)? = nil,
        sqliteDatabase: any SQLiteDatabase = LiveSQLiteDatabase(),
        applicationDirectories: [URL]? = nil
    ) {
        self.fileSystem = fileSystem
        self.timeSource = timeSource
        self.terminalSessionChecker = terminalSessionChecker
        self.sessionLinkResolver = sessionLinkResolver
        antigravityReader = AntigravityReader(fileSystem: fileSystem, database: sqliteDatabase)
        self.applicationDirectories = applicationDirectories ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileSystem.homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
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
        refreshAntigravity(now: now)
        var states = recentFiles.mapValues { RunStateJudge.runState(for: $0, now: now) }
        for (id, conversation) in recentAntigravity {
            states[id] = antigravityRunState(of: conversation, now: now)
        }
        return states
    }

    /// 마지막 sessionStates()에서 본 세션의 상세 정보를 읽는다.
    public func sessionInfo(id: String) -> SessionInfo? {
        if let file = recentFiles[id] { return makeSessionInfo(file: file, now: timeSource.now) }
        return recentAntigravity[id].map(makeAntigravityInfo(of:))
    }

    /// 최근 활동한 세션을 최신순으로 돌려준다.
    public func activeSessions() -> [SessionInfo] {
        let now = timeSource.now
        let logSessions = recentLogFiles(now: now).map { (activity: $0.activity, info: makeSessionInfo(file: $0, now: now)) }
        refreshAntigravity(now: now)
        let antigravitySessions = recentAntigravity.values.map {
            (activity: $0.lastModified, info: makeAntigravityInfo(of: $0), isWaiting: antigravityWaitingIDs.contains($0.id))
        }
        // 승인을 기다리는 대화는 개수 제한에 밀려 사라지면 안 되므로 먼저 둔다.
        return (logSessions.map { (activity: $0.activity, info: $0.info, isWaiting: false) } + antigravitySessions)
            .sorted { ($0.isWaiting ? 1 : 0, $0.activity) > ($1.isWaiting ? 1 : 0, $1.activity) }
            .prefix(SessionMonitoringPolicy.maxSessionCount)
            .sorted { $0.activity > $1.activity }
            .map(\.info)
    }

    /// 응답을 기다리는 세션과 그 이유. 마지막 sessionStates()에서 본 최근 세션만 대상으로 한다.
    public func waitingKinds() -> [String: WaitingKind] {
        let now = timeSource.now
        var kinds = recentFiles.values.reduce(into: [String: WaitingKind]()) { result, file in
            if let kind = waitingKind(for: file, now: now) { result[file.id] = kind }
        }
        for id in antigravityWaitingIDs { kinds[id] = .approval }
        return kinds
    }

    // MARK: - Antigravity

    /// 최근 대화를 읽어 recentAntigravity와 antigravityWaitingIDs를 갱신한다.
    /// 최근 activeWindow 안에 바뀐 대화, 또는 그보다 오래됐어도 승인을 기다리는 대화(waitingMaxAge까지)만 남긴다.
    private func refreshAntigravity(now: Date) {
        var recent: [String: AntigravityConversation] = [:]
        var waitingIDs: Set<String> = []
        var modelNames: [String: String] = [:]
        var usedTokens: [String: Int] = [:]
        for conversation in antigravityConversations() {
            let age = now.timeIntervalSince(conversation.lastModified)
            guard age < SessionMonitoringPolicy.waitingMaxAge else { continue }
            // 최근 활동이 없고 작업 중도 아닌 대화는 볼 필요가 없어서 대화별 DB를 읽지 않는다.
            guard age < SessionMonitoringPolicy.activeWindow || conversation.isRunning else { continue }
            let details = antigravityDetails(of: conversation.id)
            let isWaiting = conversation.isRunning && details.isWaiting
            guard age < SessionMonitoringPolicy.activeWindow || isWaiting else { continue }
            recent[conversation.id] = conversation
            if isWaiting { waitingIDs.insert(conversation.id) }
            modelNames[conversation.id] = details.modelName
            usedTokens[conversation.id] = antigravityUsedTokens(of: conversation.id)
        }
        recentAntigravity = recent
        antigravityWaitingIDs = waitingIDs
        antigravityModelNames = modelNames
        antigravityUsedTokens = usedTokens
        antigravityStepsCache = antigravityStepsCache.filter { recent[$0.key] != nil }
        antigravityTokensCache = antigravityTokensCache.filter { recent[$0.key] != nil }
    }

    private func antigravityConversations() -> [AntigravityConversation] {
        let signature = fileSignature(of: antigravityReader.summaryDatabaseURL)
        if let cached = antigravitySummaryCache, cached.signature == signature { return cached.conversations }
        // 읽지 못한 결과를 캐시하면 파일이 바뀌기 전까지 다시 읽지 못하므로, 읽지 못하면 저장하지 않는다.
        guard let conversations = antigravityReader.recentConversations() else {
            antigravitySummaryCache = nil
            return []
        }
        antigravitySummaryCache = signature.contains { $0 != nil } ? (signature, conversations) : nil
        return conversations
    }

    /// 대화별 DB는 단계가 바뀔 때마다 갱신되므로, 본 파일과 -wal의 수정 시각이 같으면 이전 결과를 다시 쓴다.
    private func antigravityDetails(of conversationID: String) -> (isWaiting: Bool, modelName: String?) {
        let signature = fileSignature(of: antigravityReader.stepsDatabaseURL(conversationID: conversationID))
        if let cached = antigravityStepsCache[conversationID], cached.signature == signature { return (cached.isWaiting, cached.modelName) }
        let waiting = antigravityReader.isWaitingForApproval(conversationID: conversationID)
        let model = antigravityReader.modelName(conversationID: conversationID)
        // 읽지 못한 결과는 캐시하지 않아 다음 조회에서 다시 읽는다.
        guard let isWaiting = waiting, let modelName = model else { return (waiting ?? false, model ?? nil) }
        antigravityStepsCache[conversationID] = (signature, isWaiting, modelName)
        return (isWaiting, modelName)
    }

    private func antigravityUsedTokens(of conversationID: String) -> Int? {
        let signature = [fileSystem.modificationDate(of: antigravityReader.transcriptURL(conversationID: conversationID))]
        if let cached = antigravityTokensCache[conversationID], cached.signature == signature { return cached.usedTokens }
        let usedTokens = antigravityReader.usedTokens(conversationID: conversationID)
        antigravityTokensCache[conversationID] = (signature, usedTokens)
        return usedTokens
    }

    /// 본 파일과 -wal 파일의 수정 시각. 파일이 없으면 nil이다.
    private func fileSignature(of databaseURL: URL) -> [Date?] {
        [databaseURL, URL(fileURLWithPath: databaseURL.path + "-wal")].map { fileSystem.modificationDate(of: $0) }
    }

    /// 승인을 기다리는 대화는 작업이 멈춘 것이 아니라 사람을 기다리는 것이라서 오래돼도 진행 중으로 본다.
    private func antigravityRunState(of conversation: AntigravityConversation, now: Date) -> SessionRunState {
        guard conversation.isRunning else { return conversation.isKilled ? .idle : .completed }
        let isFresh = now.timeIntervalSince(conversation.lastModified) < SessionMonitoringPolicy.activeWindow
        return isFresh || antigravityWaitingIDs.contains(conversation.id) ? .running : .idle
    }

    /// 줄을 눌렀을 때 열 앱. Antigravity는 기존 대화를 id로 여는 링크가 없어서(`antigravity://`는 마켓플레이스와 새 대화용) 앱 자체를 앞으로 가져온다.
    /// 앱을 찾지 못하면 nil이라 줄을 눌러도 아무 일도 하지 않는다.
    private func antigravityAppURL() -> URL? {
        applicationDirectories
            .map { $0.appendingPathComponent("Antigravity.app", isDirectory: true) }
            .first { fileSystem.directoryExists(at: $0) }
    }

    private func makeAntigravityInfo(of conversation: AntigravityConversation) -> SessionInfo {
        let isWaiting = antigravityWaitingIDs.contains(conversation.id)
        let usedTokens = antigravityUsedTokens[conversation.id]
        let modelName = antigravityModelNames[conversation.id]
        // 사용량이 있어도 창 크기를 모르는 모델이면 퍼센트를 계산하지 않는다.
        let windowTokens = usedTokens == nil ? nil : SessionMonitoringPolicy.antigravityEstimatedWindow(forModel: modelName)
        return SessionInfo(
            id: conversation.id,
            tool: .antigravity,
            projectName: conversation.workspacePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? SessionMonitoringPolicy.unknownProjectName,
            title: conversation.title,
            modelName: modelName,
            usedTokens: usedTokens,
            windowTokens: windowTokens,
            isWindowEstimated: windowTokens != nil,
            isRunning: !isWaiting && conversation.isRunning,
            waitingKind: isWaiting ? .approval : nil,
            openURL: antigravityAppURL(),
            workingDirectory: conversation.workspacePath,
            startedAt: nil,
            isTerminalSession: false
        )
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
                // 서브 에이전트와 자동 리뷰는 사용자가 따로 열어 보는 세션이 아니라서 목록, 알림, 승인 대기에서 뺀다.
                guard !isSubagentLog(at: entry.url, tool: tool, root: root) else { continue }
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

    // MARK: - 서브 에이전트 제외

    /// Claude는 기록이 subagents 폴더 아래에 있으면, Codex는 기록 첫 줄의 source가 subagent이면 서브 에이전트다.
    /// 루트 아래의 경로 조각만 보므로 홈이나 프로젝트 이름에 같은 단어가 있어도 영향이 없다.
    private func isSubagentLog(at url: URL, tool: AiTool, root: URL) -> Bool {
        switch tool {
        case .claude:
            return url.pathComponents.dropFirst(root.pathComponents.count)
                .contains(SessionMonitoringPolicy.claudeSubagentDirectoryName)
        case .codex:
            return codexOrigin(of: url).isSubagent
        case .antigravity:
            return false
        }
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
        case .antigravity:
            return false
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
                title: codexOrigin(of: file.url).threadID.flatMap(codexTitle(forThreadID:)),
                startedAt: startedAt,
                isRunning: isRunning,
                waitingKind: waitingKind
            )
        case .antigravity:
            // 기록 파일로 읽지 않는 툴이라 이 경로에 오지 않는다. 오더라도 알려진 정보만으로 만든다.
            return SessionInfo(
                id: file.id, tool: .antigravity, projectName: SessionMonitoringPolicy.unknownProjectName, title: nil,
                modelName: nil, usedTokens: nil, windowTokens: nil, isWindowEstimated: false,
                isRunning: isRunning, waitingKind: waitingKind, openURL: nil, workingDirectory: nil,
                startedAt: startedAt, isTerminalSession: false
            )
        }
    }

    /// 제목 파일을 읽을 수 없거나 그 스레드의 제목이 없으면 nil이다. 그러면 화면에는 프로젝트 이름이 나온다.
    private func codexTitle(forThreadID threadID: String) -> String? {
        let url = fileSystem.homeDirectory.appendingPathComponent(SessionMonitoringPolicy.codexTitleIndexPath)
        guard let modifiedAt = fileSystem.modificationDate(of: url) else {
            codexTitleCache = nil
            return nil
        }
        if codexTitleCache?.modifiedAt != modifiedAt {
            // 읽기에 실패하면 빈 제목을 캐시하지 않고 다음 조회에서 다시 읽는다.
            guard let data = fileSystem.readAll(of: url) else {
                codexTitleCache = nil
                return nil
            }
            codexTitleCache = (modifiedAt, CodexTitleIndex.titles(from: data))
        }
        return codexTitleCache?.titles[threadID]
    }

    private func codexOrigin(of url: URL) -> CodexOrigin {
        if let cached = codexOriginCache[url.path] { return cached }
        guard let origin = originReader.origin(of: url) else { return .unknown }
        codexOriginCache[url.path] = origin
        return origin
    }
}
