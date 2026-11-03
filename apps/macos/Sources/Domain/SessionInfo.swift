import Foundation

public struct SessionInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let tool: AiTool
    public let projectName: String
    public let title: String?
    public let modelName: String?
    public let usedTokens: Int?
    public let windowTokens: Int?
    public let isWindowEstimated: Bool
    public let isRunning: Bool
    /// 사람의 응답(승인 또는 답변)을 기다리는 중이면 그 이유. 이때 isRunning은 false다(진행 중이 아니라 사람을 기다리는 중이다).
    public let waitingKind: WaitingKind?
    /// 줄을 눌렀을 때 그 세션이 있는 곳을 여는 링크. 연결할 곳을 찾지 못하면 nil이다.
    public let openURL: URL?
    public let workingDirectory: String?
    public let startedAt: Date?
    /// 터미널(CLI)에서 시작한 세션인지. 터미널 탭에서 돌고 있으면 true다.
    public let isTerminalSession: Bool

    public var canOpen: Bool { openURL != nil || isTerminalSession }
    public var isWaitingForUser: Bool { waitingKind != nil }

    public init(
        id: String,
        tool: AiTool,
        projectName: String,
        title: String?,
        modelName: String?,
        usedTokens: Int?,
        windowTokens: Int?,
        isWindowEstimated: Bool,
        isRunning: Bool,
        waitingKind: WaitingKind?,
        openURL: URL?,
        workingDirectory: String?,
        startedAt: Date?,
        isTerminalSession: Bool
    ) {
        self.id = id
        self.tool = tool
        self.projectName = projectName
        self.title = title
        self.modelName = modelName
        self.usedTokens = usedTokens
        self.windowTokens = windowTokens
        self.isWindowEstimated = isWindowEstimated
        self.isRunning = isRunning
        self.waitingKind = waitingKind
        self.openURL = openURL
        self.workingDirectory = workingDirectory
        self.startedAt = startedAt
        self.isTerminalSession = isTerminalSession
    }
}
