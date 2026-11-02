import Foundation

// 짧게 끝나는 외부 명령(ps, lsof, Orca CLI)을 실행하고 표준 출력을 돌려준다.
// 오래 떠 있는 프로세스(codex app-server)는 필요한 이슈에서 추가한다.
public protocol ProcessRunner: Sendable {
    // 실행 파일을 띄우지 못하면 throw한다. 종료 코드는 판단하지 않고 출력만 돌려준다(원본 동작).
    func run(executable: String, arguments: [String]) throws -> String
    /// pid의 프로세스가 살아 있는지. 권한이 없어서 신호를 보낼 수 없는 프로세스(EPERM)도 살아 있는 것으로 본다.
    func isProcessAlive(pid: Int) -> Bool
}

public struct SystemProcessRunner: ProcessRunner {
    public init() {}

    public func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    public func isProcessAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0 || errno == EPERM
    }
}
