import Foundation

// 터미널(tty)에 붙어 있는 CLI 프로세스 하나.
public struct TerminalProcess: Sendable, Equatable {
    public let pid: Int
    public let commandName: String
    public let tty: String
    public let startedAt: Date
    public let workingDirectory: String?

    public init(pid: Int, commandName: String, tty: String, startedAt: Date, workingDirectory: String?) {
        self.pid = pid
        self.commandName = commandName
        self.tty = tty
        self.startedAt = startedAt
        self.workingDirectory = workingDirectory
    }
}
