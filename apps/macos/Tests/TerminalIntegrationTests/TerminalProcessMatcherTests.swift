import Domain
import Foundation
import Testing
@testable import TerminalIntegration

struct TerminalProcessMatcherTests {
    private let sessionStart = Date(timeIntervalSince1970: 1_000_000)

    private func makeProcess(pid: Int, name: String = "claude", startedAfter offset: TimeInterval, directory: String? = "/w/app") -> TerminalProcess {
        TerminalProcess(pid: pid, commandName: name, tty: "ttys00\(pid % 10)", startedAt: sessionStart.addingTimeInterval(offset), workingDirectory: directory)
    }

    // AC-8
    @Test func picksProcessStartedJustBeforeSession() {
        let processes = [
            makeProcess(pid: 1, startedAfter: -600),
            makeProcess(pid: 2, startedAfter: -60),
            makeProcess(pid: 3, startedAfter: 300)
        ]
        let matched = TerminalProcessMatcher.match(processes: processes, tool: .claude, workingDirectory: "/w/app", startedAt: sessionStart)
        #expect(matched?.pid == 2)
    }

    // AC-8
    @Test func filtersByToolAndNormalizedWorkingDirectory() {
        let processes = [
            makeProcess(pid: 1, name: "codex", startedAfter: -60),
            makeProcess(pid: 2, startedAfter: -60, directory: "/w/other"),
            makeProcess(pid: 3, startedAfter: -60, directory: nil),
            makeProcess(pid: 4, startedAfter: -60, directory: "/w/app")
        ]
        #expect(TerminalProcessMatcher.match(processes: processes, tool: .claude, workingDirectory: "/w/app/", startedAt: sessionStart)?.pid == 4)
        #expect(TerminalProcessMatcher.match(processes: processes, tool: .codex, workingDirectory: "/w/app", startedAt: sessionStart)?.pid == 1)
        #expect(TerminalProcessMatcher.match(processes: processes, tool: .claude, workingDirectory: "/nowhere", startedAt: sessionStart) == nil)
    }

    // AC-8
    @Test func picksFirstCandidateWithoutStartTimeOrSingleCandidate() {
        let processes = [makeProcess(pid: 1, startedAfter: -600), makeProcess(pid: 2, startedAfter: -60)]
        #expect(TerminalProcessMatcher.match(processes: processes, tool: .claude, workingDirectory: "/w/app", startedAt: nil)?.pid == 1)
        #expect(TerminalProcessMatcher.match(processes: [processes[1]], tool: .claude, workingDirectory: "/w/app", startedAt: sessionStart)?.pid == 2)
        #expect(TerminalProcessMatcher.match(processes: [], tool: .claude, workingDirectory: "/w/app", startedAt: sessionStart) == nil)
    }
}
