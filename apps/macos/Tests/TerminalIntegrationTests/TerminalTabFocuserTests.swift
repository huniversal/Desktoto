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

    private let cmuxCLI = "/Applications/cmux.app/Contents/Resources/bin/cmux"
    private let firstSurfaceID = "02C0DC0F-BA32-4C64-A63E-E94D7E120983"
    private let secondSurfaceID = "31C415A9-5968-4F29-AA48-3A28BDDBE760"
    private let cmuxTree = """
      10 1 /Applications/cmux.app/Contents/MacOS/cmux
      20 10 /bin/zsh
      30 20 /usr/local/bin/claude
      40 10 /bin/zsh
      50 40 /usr/local/bin/claude
    """

    private func makeCmuxProcess(pid: Int) -> TerminalProcess {
        TerminalProcess(pid: pid, commandName: "claude", tty: "ttys00\(pid / 10)", startedAt: Date(), workingDirectory: "/w/app")
    }

    // AC-2, AC-3
    @Test func focusesCmuxPanelByEnvironmentSurfaceID() {
        let runner = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": cmuxTree,
            "/bin/ps eww -p 30": "PID TTY STAT TIME COMMAND\n30 s003 S+ 0:01 claude HOME=/Users/me CMUX_SURFACE_ID=\(firstSurfaceID)",
            "\(cmuxCLI) focus-panel --panel \(firstSurfaceID)": "OK surface:1 workspace:1\n"
        ])
        let script = RecordingAppleScriptRunner { _ in true }
        let opener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2"])
        #expect(makeFocuser(runner: runner, script: script, opener: opener).focus(process: makeCmuxProcess(pid: 30), sessionTitle: nil))
        #expect(opener.activatedBundleIdentifiers == ["com.cmuxterm.app"])
        #expect(script.sources.isEmpty)
    }

    // AC-4: 같은 작업 폴더의 두 세션은 각자 자기 패널 UUID로 이동한다.
    @Test func focusesTheCorrectPanelWhenSessionsShareAFolder() {
        let runner = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": cmuxTree,
            "/bin/ps eww -p 30": "30 claude CMUX_SURFACE_ID=\(firstSurfaceID)",
            "/bin/ps eww -p 50": "50 claude CMUX_SURFACE_ID=\(secondSurfaceID)",
            "\(cmuxCLI) focus-panel --panel \(firstSurfaceID)": "OK surface:1 workspace:1",
            "\(cmuxCLI) focus-panel --panel \(secondSurfaceID)": "OK surface:2 workspace:2"
        ])
        let script = RecordingAppleScriptRunner { _ in true }
        let focuser = makeFocuser(runner: runner, script: script, opener: FakeURLOpener())
        #expect(focuser.focus(process: makeCmuxProcess(pid: 50), sessionTitle: nil))
        #expect(runner.commands.last == "\(cmuxCLI) focus-panel --panel \(secondSurfaceID)")
        #expect(focuser.focus(process: makeCmuxProcess(pid: 30), sessionTitle: nil))
        #expect(runner.commands.last == "\(cmuxCLI) focus-panel --panel \(firstSurfaceID)")
    }

    // AC-10
    @Test func activatesTheIDEAppForIntegratedTerminals() {
        let cases = [
            ("/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper", "com.microsoft.VSCode"),
            ("/Applications/Antigravity IDE.app/Contents/Frameworks/Antigravity IDE Helper.app/Contents/MacOS/Antigravity IDE Helper", "com.google.antigravity-ide")
        ]
        cases.forEach { helperPath, bundleIdentifier in
            let tree = """
              10 1 \(helperPath)
              20 10 /bin/zsh
              30 20 claude
            """
            let runner = ScriptedProcessRunner(outputs: ["/bin/ps -axo pid=,ppid=,comm=": tree])
            let script = RecordingAppleScriptRunner { _ in true }
            let opener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2"])
            #expect(makeFocuser(runner: runner, script: script, opener: opener).focus(process: process, sessionTitle: nil))
            #expect(opener.activatedBundleIdentifiers == [bundleIdentifier])
            #expect(script.sources.isEmpty)
            #expect(runner.commands == ["/bin/ps -axo pid=,ppid=,comm="])
        }
    }

    // AC-10: Orca와 cmux 안에서 IDE가 조상이어도(예: IDE에서 연 터미널이 아님) 기존 앱이 우선한다.
    @Test func prefersOrcaAndCmuxOverIDEAncestors() {
        let tree = """
          5 1 /Applications/Visual Studio Code.app/Contents/MacOS/Code
          10 5 /Applications/cmux.app/Contents/MacOS/cmux
          20 10 /bin/zsh
          30 20 /usr/local/bin/claude
        """
        let runner = ScriptedProcessRunner(outputs: ["/bin/ps -axo pid=,ppid=,comm=": tree])
        let opener = FakeURLOpener()
        let script = RecordingAppleScriptRunner { _ in true }
        // cmux 경로로 갔지만 환경 출력이 없어 실패한다. IDE 앱은 활성화되지 않는다.
        #expect(!makeFocuser(runner: runner, script: script, opener: opener).focus(process: process, sessionTitle: nil))
        #expect(opener.activatedBundleIdentifiers.isEmpty)
    }

    // AC-5
    @Test func cmuxFailuresReturnFalseWithoutActivating() {
        let opener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2"])
        let script = RecordingAppleScriptRunner { _ in true }
        let environment = "30 claude CMUX_SURFACE_ID=\(firstSurfaceID)"

        // 소켓 제어 모드가 기본값이면 cmux CLI의 표준 출력이 비어 있다.
        let socketDenied = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": cmuxTree,
            "/bin/ps eww -p 30": environment,
            "\(cmuxCLI) focus-panel --panel \(firstSurfaceID)": ""
        ])
        #expect(!makeFocuser(runner: socketDenied, script: script, opener: opener).focus(process: makeCmuxProcess(pid: 30), sessionTitle: nil))

        let noSurfaceID = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": cmuxTree,
            "/bin/ps eww -p 30": "30 claude HOME=/Users/me"
        ])
        #expect(!makeFocuser(runner: noSurfaceID, script: script, opener: opener).focus(process: makeCmuxProcess(pid: 30), sessionTitle: nil))

        let environmentUnreadable = ScriptedProcessRunner(outputs: ["/bin/ps -axo pid=,ppid=,comm=": cmuxTree])
        #expect(!makeFocuser(runner: environmentUnreadable, script: script, opener: opener).focus(process: makeCmuxProcess(pid: 30), sessionTitle: nil))

        let cliUnavailable = ScriptedProcessRunner(outputs: [
            "/bin/ps -axo pid=,ppid=,comm=": cmuxTree,
            "/bin/ps eww -p 30": environment
        ])
        #expect(!makeFocuser(runner: cliUnavailable, script: script, opener: opener).focus(process: makeCmuxProcess(pid: 30), sessionTitle: nil))

        #expect(opener.activatedBundleIdentifiers.isEmpty)
        #expect(script.sources.isEmpty)
    }
}
