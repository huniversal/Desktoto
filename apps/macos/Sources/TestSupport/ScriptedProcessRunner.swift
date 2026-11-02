import Boundaries
import Synchronization

// 명령별로 정해 둔 출력을 돌려주는 가짜 ProcessRunner. 정해 두지 않은 명령은 실행 실패로 본다.
public final class ScriptedProcessRunner: ProcessRunner {
    public struct UnscriptedCommandError: Error {
        public let command: String
    }

    private let outputs: [String: String]
    private let aliveProcessIDs: Set<Int>
    private let recordedCommands = Mutex<[String]>([])

    // 키는 `executable arguments...`를 공백으로 이은 문자열이다.
    public init(outputs: [String: String], aliveProcessIDs: Set<Int> = []) {
        self.outputs = outputs
        self.aliveProcessIDs = aliveProcessIDs
    }

    public var commands: [String] {
        recordedCommands.withLock { $0 }
    }

    public func run(executable: String, arguments: [String]) throws -> String {
        let command = ([executable] + arguments).joined(separator: " ")
        recordedCommands.withLock { $0.append(command) }
        guard let output = outputs[command] else { throw UnscriptedCommandError(command: command) }
        return output
    }

    public func isProcessAlive(pid: Int) -> Bool {
        aliveProcessIDs.contains(pid)
    }
}
