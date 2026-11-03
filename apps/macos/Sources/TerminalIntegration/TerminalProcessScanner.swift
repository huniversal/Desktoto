import Boundaries
import Foundation

// 터미널(tty)에 붙어 있는 CLI 프로세스를 ps와 lsof로 찾는다. 데스크탑 앱이 띄운 프로세스는 tty가 없어서 제외된다.
// 명령을 실행하지 못하면 빈 목록(작업 폴더는 nil)으로 돌려준다(원본 동작).
public struct TerminalProcessScanner: Sendable {
    private let processRunner: any ProcessRunner

    public init(processRunner: any ProcessRunner) {
        self.processRunner = processRunner
    }

    // commandNames에 든 이름의 프로세스만 다룬다(작업 폴더를 읽는 lsof 실행을 줄인다). now는 시작 시각 계산의 기준 시점이다.
    public func listProcesses(commandNames: Set<String>, now: Date) -> [TerminalProcess] {
        guard let output = try? processRunner.run(executable: "/bin/ps", arguments: ["-axo", "pid=,tty=,etime=,comm="]) else {
            return []
        }
        return ProcessListParser.parseProcessRows(output)
            .filter { commandNames.contains($0.commandName) }
            .map { row in
                TerminalProcess(
                    pid: row.pid,
                    commandName: row.commandName,
                    tty: row.tty,
                    startedAt: now.addingTimeInterval(-row.elapsedSeconds),
                    workingDirectory: readWorkingDirectory(pid: row.pid)
                )
            }
    }

    private func readWorkingDirectory(pid: Int) -> String? {
        guard let output = try? processRunner.run(
            executable: "/usr/sbin/lsof",
            arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]
        ) else { return nil }
        return ProcessListParser.parseWorkingDirectory(output)
    }
}
