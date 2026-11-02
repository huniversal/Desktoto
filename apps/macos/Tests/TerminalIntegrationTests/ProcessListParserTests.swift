import Boundaries
import Foundation
import TestSupport
import Testing
@testable import TerminalIntegration

struct ProcessListParserTests {
    // AC-1
    @Test func parsesRowsAndSkipsNoTTYAndMalformedLines() {
        let output = """
          101 ttys001     05:30 /usr/local/bin/claude
          102 ??          01:00 /Applications/Claude.app/Contents/MacOS/claude
          abc ttys002     01:00 /usr/bin/codex
          103 ttys003 1-02:03:04 /opt/bin/codex
          104 ttys004     01:00
          105 ttys005     bad /usr/bin/claude
        """
        let rows = ProcessListParser.parseProcessRows(output)
        #expect(rows == [
            .init(pid: 101, tty: "ttys001", elapsedSeconds: 330, commandName: "claude"),
            .init(pid: 103, tty: "ttys003", elapsedSeconds: 93_784, commandName: "codex")
        ])
    }

    // AC-1
    @Test func scannerFiltersByCommandNameAndComputesStartTime() {
        let now = Date(timeIntervalSince1970: 10_000)
        let runner = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,tty=,etime=,comm=": """
              101 ttys001 05:30 /usr/local/bin/claude
              102 ttys002 00:10 /usr/bin/vim
            """,
            "/usr/sbin/lsof -a -p 101 -d cwd -Fn": "p101\nfcwd\nn/Users/me/project\n"
        ])
        let processes = TerminalProcessScanner(processRunner: runner).listProcesses(commandNames: ["claude"], now: now)
        #expect(processes == [
            TerminalProcess(
                pid: 101, commandName: "claude", tty: "ttys001",
                startedAt: now.addingTimeInterval(-330), workingDirectory: "/Users/me/project"
            )
        ])
        #expect(!runner.commands.contains { $0.contains("-p 102") })
    }

    @Test func scannerReturnsEmptyWhenPsFails() {
        let runner = ScriptedProcessRunner(outputs: [:])
        #expect(TerminalProcessScanner(processRunner: runner).listProcesses(commandNames: ["claude"], now: Date()).isEmpty)
    }

    // AC-2
    @Test func convertsElapsedTime() {
        #expect(ProcessListParser.convertElapsedTimeToSeconds("05:30") == 330)
        #expect(ProcessListParser.convertElapsedTimeToSeconds("01:02:03") == 3_723)
        #expect(ProcessListParser.convertElapsedTimeToSeconds("2-01:02:03") == 176_523)
        #expect(ProcessListParser.convertElapsedTimeToSeconds("") == nil)
        #expect(ProcessListParser.convertElapsedTimeToSeconds("abc") == nil)
        #expect(ProcessListParser.convertElapsedTimeToSeconds("1:2:3:4") == nil)
    }

    // AC-3
    @Test func parsesWorkingDirectory() {
        #expect(ProcessListParser.parseWorkingDirectory("p1\nfcwd\nn/Users/me/a b\n") == "/Users/me/a b")
        #expect(ProcessListParser.parseWorkingDirectory("") == nil)
        #expect(ProcessListParser.parseWorkingDirectory("p1\nfcwd\n") == nil)
    }

    // AC-4
    @Test func findsOrcaAncestor() {
        let tree = ProcessListParser.parseProcessTree("""
          10 1 /Applications/Orca.app/Contents/MacOS/Orca
          20 10 /bin/zsh
          30 20 /usr/local/bin/claude
          40 1 /bin/zsh
          50 40 /usr/local/bin/claude
        """)
        #expect(ProcessListParser.findAncestorAppPath(of: 30, appName: "Orca.app", in: tree) == "/Applications/Orca.app")
        #expect(ProcessListParser.findAncestorAppPath(of: 50, appName: "Orca.app", in: tree) == nil)
    }

    // AC-4
    @Test func ancestorSearchStopsOnCycle() {
        let tree = ProcessListParser.ProcessTree(parentOf: [2: 3, 3: 2], pathOf: [2: "/bin/a", 3: "/bin/b"])
        #expect(ProcessListParser.findAncestorAppPath(of: 2, appName: "Orca.app", in: tree) == nil)
    }
}
