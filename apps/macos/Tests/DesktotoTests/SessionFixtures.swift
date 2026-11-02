import Domain
import Foundation

func makeSession(
    id: String = "session-1",
    projectName: String = "project",
    title: String? = nil,
    isRunning: Bool = false,
    waitingKind: WaitingKind? = nil
) -> SessionInfo {
    SessionInfo(
        id: id,
        tool: .claude,
        projectName: projectName,
        title: title,
        modelName: nil,
        usedTokens: nil,
        windowTokens: nil,
        isWindowEstimated: false,
        isRunning: isRunning,
        waitingKind: waitingKind,
        openURL: nil,
        workingDirectory: nil,
        startedAt: nil,
        isTerminalSession: false
    )
}
