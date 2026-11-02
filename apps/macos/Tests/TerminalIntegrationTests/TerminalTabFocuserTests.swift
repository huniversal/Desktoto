import Boundaries
import Foundation
import TestSupport
import Testing
@testable import TerminalIntegration

struct TerminalTabFocuserTests {
    private let process = TerminalProcess(
        pid: 30, commandName: "claude", tty: "ttys003", startedAt: Date(), workingDirectory: "/w/app"
    )
    private let nonOrcaTree = "30 20 /usr/local/bin/claude\n20 1 /bin/zsh\n"

    private func makeFocuser(
        runner: ScriptedProcessRunner,
        script: RecordingAppleScriptRunner,
        opener: FakeURLOpener
    ) -> TerminalTabFocuser {
        TerminalTabFocuser(processRunner: runner, appleScriptRunner: script, urlOpener: opener)
    }

    // AC-6
    @Test func skipsAppsThatAreNotRunning() {
        let runner = ScriptedProcessRunner(outputs: ["/bin/ps -axo pid=,ppid=,comm=": nonOrcaTree])
        let script = RecordingAppleScriptRunner { _ in true }
        let focuser = makeFocuser(runner: runner, script: script, opener: FakeURLOpener())
        #expect(!focuser.focus(process: process, sessionTitle: nil))
        #expect(script.sources.isEmpty)
    }

    // AC-6
    @Test func stopsAtFirstAppThatFindsTheTab() {
        let runner = ScriptedProcessRunner(outputs: ["/bin/ps -axo pid=,ppid=,comm=": nonOrcaTree])
        let script = RecordingAppleScriptRunner { $0.contains("application \"Terminal\"") }
        let opener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2", "com.apple.Terminal"])
        #expect(makeFocuser(runner: runner, script: script, opener: opener).focus(process: process, sessionTitle: nil))
        #expect(script.sources.count == 2)
        #expect(script.sources.allSatisfy { $0.contains("/dev/ttys003") })

        let firstHit = RecordingAppleScriptRunner { _ in true }
        #expect(makeFocuser(runner: runner, script: firstHit, opener: opener).focus(process: process, sessionTitle: nil))
        #expect(firstHit.sources.count == 1)
    }

    // AC-6
    @Test func scriptErrorMovesOnToNextApp() {
        struct Denied: Error {}
        let runner = ScriptedProcessRunner(outputs: ["/bin/ps -axo pid=,ppid=,comm=": nonOrcaTree])
        let script = RecordingAppleScriptRunner { source in
            if source.contains("iTerm2") { throw Denied() }
            return true
        }
        let opener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2", "com.apple.Terminal"])
        #expect(makeFocuser(runner: runner, script: script, opener: opener).focus(process: process, sessionTitle: nil))
    }

    // AC-6
    @Test func escapesTTYInScript() {
        #expect(TerminalScripts.escape("a\"b\\c") == "a\\\"b\\\\c")
        #expect(TerminalScripts.makeITermScript(tty: "/dev/x\" & quit").contains("/dev/x\\\" & quit"))
    }

    private let orcaCLI = "/Applications/Orca.app/Contents/Resources/bin/orca"
    private let orcaTree = """
      10 1 /Applications/Orca.app/Contents/MacOS/Orca
      20 10 /bin/zsh
      30 20 /usr/local/bin/claude
    """

    // AC-6
    @Test func focusesOrcaTabThroughCLI() {
        let runner = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": orcaTree,
            "\(orcaCLI) terminal list --json": "{\"result\": {\"terminals\": [{\"handle\": \"h1\", \"worktreePath\": \"/w\"}]}}",
            "\(orcaCLI) terminal switch --terminal h1 --json": "{\"ok\": true}"
        ])
        let script = RecordingAppleScriptRunner { _ in true }
        let opener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2"])
        #expect(makeFocuser(runner: runner, script: script, opener: opener).focus(process: process, sessionTitle: nil))
        #expect(script.sources.isEmpty)
        #expect(opener.activatedBundleIdentifiers == ["com.stablyai.orca"])
    }

    // AC-6
    @Test func orcaFailuresReturnFalseWithoutActivating() {
        let list = "{\"result\": {\"terminals\": [{\"handle\": \"h1\", \"worktreePath\": \"/w\"}]}}"
        let opener = FakeURLOpener()
        let script = RecordingAppleScriptRunner { _ in true }

        let switchFails = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": orcaTree,
            "\(orcaCLI) terminal list --json": list,
            "\(orcaCLI) terminal switch --terminal h1 --json": "{\"ok\": false}"
        ])
        #expect(!makeFocuser(runner: switchFails, script: script, opener: opener).focus(process: process, sessionTitle: nil))

        let noMatch = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": orcaTree,
            "\(orcaCLI) terminal list --json": "{\"result\": {\"terminals\": []}}"
        ])
        #expect(!makeFocuser(runner: noMatch, script: script, opener: opener).focus(process: process, sessionTitle: nil))

        let noDirectory = TerminalProcess(pid: 30, commandName: "claude", tty: "ttys003", startedAt: Date(), workingDirectory: nil)
        #expect(!makeFocuser(runner: switchFails, script: script, opener: opener).focus(process: noDirectory, sessionTitle: nil))
        #expect(opener.activatedBundleIdentifiers.isEmpty)
        #expect(script.sources.isEmpty)
    }
}
