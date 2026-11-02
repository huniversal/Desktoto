import Boundaries
import Domain
import Foundation
import TestSupport
import Testing
@testable import TerminalIntegration

struct ProcessTerminalSessionCheckerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func sessionsDirectory(_ fileSystem: InMemoryFileSystem) -> URL {
        fileSystem.homeDirectory.appendingPathComponent(".claude/sessions")
    }

    private func addSessionFile(_ fileSystem: InMemoryFileSystem, name: String, text: String) {
        fileSystem.addFile(at: sessionsDirectory(fileSystem).appendingPathComponent("\(name).json"), text: text, modifiedAt: now)
    }

    private func makeChecker(
        fileSystem: InMemoryFileSystem,
        runner: ScriptedProcessRunner = ScriptedProcessRunner(outputs: [:]),
        timeSource: FixedTimeSource
    ) -> ProcessTerminalSessionChecker {
        ProcessTerminalSessionChecker(fileSystem: fileSystem, processRunner: runner, timeSource: timeSource)
    }

    // AC-9
    @Test func claudeSessionIsOpenOnlyWhileItsProcessIsAlive() {
        let fileSystem = InMemoryFileSystem()
        addSessionFile(fileSystem, name: "101", text: #"{"pid": 101, "sessionId": "alive"}"#)
        addSessionFile(fileSystem, name: "102", text: #"{"pid": 102, "sessionId": "dead"}"#)
        addSessionFile(fileSystem, name: "bad", text: "not json")
        addSessionFile(fileSystem, name: "partial", text: #"{"pid": 103}"#)
        let checker = makeChecker(
            fileSystem: fileSystem,
            runner: ScriptedProcessRunner(outputs: [:], aliveProcessIDs: [101, 103]),
            timeSource: FixedTimeSource(now: now)
        )

        #expect(!checker.isClosed(sessionID: "alive", tool: .claude, workingDirectory: nil))
        #expect(checker.isClosed(sessionID: "dead", tool: .claude, workingDirectory: nil))
        #expect(checker.isClosed(sessionID: "unknown", tool: .claude, workingDirectory: nil))
    }

    // AC-9
    @Test func claudeSessionIsNotClosedWhenFolderIsMissingButClosedWhenEmpty() {
        let missing = InMemoryFileSystem()
        #expect(!makeChecker(fileSystem: missing, timeSource: FixedTimeSource(now: now))
            .isClosed(sessionID: "s", tool: .claude, workingDirectory: nil))

        let empty = InMemoryFileSystem()
        empty.addDirectory(at: sessionsDirectory(empty))
        #expect(makeChecker(fileSystem: empty, timeSource: FixedTimeSource(now: now))
            .isClosed(sessionID: "s", tool: .claude, workingDirectory: nil))
    }

    // AC-9
    @Test func claudeResultIsCachedForOneSecond() {
        let fileSystem = InMemoryFileSystem()
        addSessionFile(fileSystem, name: "101", text: #"{"pid": 101, "sessionId": "s1"}"#)
        let timeSource = FixedTimeSource(now: now)
        let checker = makeChecker(
            fileSystem: fileSystem,
            runner: ScriptedProcessRunner(outputs: [:], aliveProcessIDs: [101, 102]),
            timeSource: timeSource
        )
        #expect(checker.isClosed(sessionID: "s2", tool: .claude, workingDirectory: nil))

        addSessionFile(fileSystem, name: "102", text: #"{"pid": 102, "sessionId": "s2"}"#)
        timeSource.advance(by: 0.5)
        #expect(checker.isClosed(sessionID: "s2", tool: .claude, workingDirectory: nil))
        timeSource.advance(by: 1)
        #expect(!checker.isClosed(sessionID: "s2", tool: .claude, workingDirectory: nil))
    }

    private let psCommand = "/bin/ps -axo pid=,tty=,etime=,comm="

    // AC-10
    @Test func codexSessionIsOpenWhileTerminalProcessRunsInSameDirectory() {
        let runner = ScriptedProcessRunner(outputs: [
            psCommand: "500 ttys001 01:00 /usr/local/bin/codex\n501 ?? 01:00 /Applications/Codex.app/codex\n",
            "/usr/sbin/lsof -a -p 500 -d cwd -Fn": "p500\nfcwd\nn/w/app\n"
        ])
        let checker = makeChecker(fileSystem: InMemoryFileSystem(), runner: runner, timeSource: FixedTimeSource(now: now))

        #expect(!checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w/app"))
        #expect(!checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w/app/"))
        #expect(checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w/other"))
    }

    // AC-10
    @Test func codexSessionIsNotClosedWhenDirectoryIsUnknownOrUnreadable() {
        let unreadable = ScriptedProcessRunner(outputs: [
            psCommand: "500 ttys001 01:00 /usr/local/bin/codex\n",
            "/usr/sbin/lsof -a -p 500 -d cwd -Fn": ""
        ])
        let checker = makeChecker(fileSystem: InMemoryFileSystem(), runner: unreadable, timeSource: FixedTimeSource(now: now))
        #expect(!checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w/other"))
        #expect(!checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: nil))
    }

    // AC-10
    @Test func codexProcessListIsCachedForFiveSeconds() {
        let runner = ScriptedProcessRunner(outputs: [psCommand: ""])
        let timeSource = FixedTimeSource(now: now)
        let checker = makeChecker(fileSystem: InMemoryFileSystem(), runner: runner, timeSource: timeSource)

        _ = checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w")
        timeSource.advance(by: 4)
        _ = checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w")
        #expect(runner.commands.count == 1)
        timeSource.advance(by: 2)
        _ = checker.isClosed(sessionID: "t", tool: .codex, workingDirectory: "/w")
        #expect(runner.commands.count == 2)
    }
}
