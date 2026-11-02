import Domain
import Foundation

func makeSession(
    id: String = "session-1",
    projectName: String = "project",
    title: String? = nil,
    modelName: String? = nil,
    usedTokens: Int? = nil,
    windowTokens: Int? = nil,
    isWindowEstimated: Bool = false,
    isRunning: Bool = false,
    waitingKind: WaitingKind? = nil,
    openURL: URL? = nil,
    isTerminalSession: Bool = false
) -> SessionInfo {
    SessionInfo(
        id: id,
        tool: .claude,
        projectName: projectName,
        title: title,
        modelName: modelName,
        usedTokens: usedTokens,
        windowTokens: windowTokens,
        isWindowEstimated: isWindowEstimated,
        isRunning: isRunning,
        waitingKind: waitingKind,
        openURL: openURL,
        workingDirectory: nil,
        startedAt: nil,
        isTerminalSession: isTerminalSession
    )
}
