import Foundation
import Testing
@testable import TerminalIntegration

struct OrcaTerminalSelectorTests {
    // AC-5
    @Test func parsesTerminalsAndSkipsIncompleteEntries() {
        let json = """
        {"ok": true, "result": {"terminals": [
          {"handle": "h1", "worktreePath": "/w/a", "title": "claude"},
          {"handle": "h2"},
          {"worktreePath": "/w/b"}
        ]}}
        """
        #expect(OrcaTerminalSelector.parseTerminals(Data(json.utf8)) == [
            OrcaTerminal(handle: "h1", worktreePath: "/w/a", title: "claude")
        ])
    }

    // AC-5
    @Test func malformedJSONGivesEmptyList() {
        #expect(OrcaTerminalSelector.parseTerminals(Data("not json".utf8)).isEmpty)
        #expect(OrcaTerminalSelector.parseTerminals(Data("{\"result\": {}}".utf8)).isEmpty)
    }

    // AC-5
    @Test func picksDeepestContainingWorktree() {
        let terminals = [
            OrcaTerminal(handle: "root", worktreePath: "/w", title: nil),
            OrcaTerminal(handle: "deep", worktreePath: "/w/app", title: nil),
            OrcaTerminal(handle: "other", worktreePath: "/w/app2", title: nil)
        ]
        #expect(OrcaTerminalSelector.pickHandle(terminals: terminals, workingDirectory: "/w/app/src", sessionTitle: nil) == "deep")
        #expect(OrcaTerminalSelector.pickHandle(terminals: terminals, workingDirectory: "/w/app", sessionTitle: nil) == "deep")
        #expect(OrcaTerminalSelector.pickHandle(terminals: terminals, workingDirectory: "/x", sessionTitle: nil) == nil)
    }

    // AC-5
    @Test func prefersTitleMatchAmongSameWorktree() {
        let terminals = [
            OrcaTerminal(handle: "a", worktreePath: "/w", title: "shell"),
            OrcaTerminal(handle: "b", worktreePath: "/w", title: "fix login bug")
        ]
        #expect(OrcaTerminalSelector.pickHandle(terminals: terminals, workingDirectory: "/w", sessionTitle: "login") == "b")
        #expect(OrcaTerminalSelector.pickHandle(terminals: terminals, workingDirectory: "/w", sessionTitle: "none") == "a")
        #expect(OrcaTerminalSelector.pickHandle(terminals: terminals, workingDirectory: "/w", sessionTitle: "") == "a")
    }

    // AC-5
    @Test func detectsSwitchSuccess() {
        #expect(OrcaTerminalSelector.hasSucceeded(Data("{\"ok\": true}".utf8)))
        #expect(!OrcaTerminalSelector.hasSucceeded(Data("{\"ok\": false}".utf8)))
        #expect(!OrcaTerminalSelector.hasSucceeded(Data("garbage".utf8)))
    }
}
