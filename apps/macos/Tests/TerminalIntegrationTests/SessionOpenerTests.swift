import Boundaries
import Domain
import Foundation
import TestSupport
import Testing
@testable import TerminalIntegration

struct SessionOpenerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSession(openURL: URL? = nil, isTerminalSession: Bool, workingDirectory: String? = "/w/app") -> SessionInfo {
        SessionInfo(
            id: "s1", tool: .claude, projectName: "app", title: nil, modelName: nil, usedTokens: nil, windowTokens: nil,
            isWindowEstimated: false, isRunning: false, waitingKind: nil, openURL: openURL,
            workingDirectory: workingDirectory, startedAt: now.addingTimeInterval(-30), isTerminalSession: isTerminalSession
        )
    }

    private func makeOpener(
        runner: ScriptedProcessRunner = ScriptedProcessRunner(outputs: [:]),
        script: RecordingAppleScriptRunner = RecordingAppleScriptRunner { _ in true },
        urlOpener: FakeURLOpener
    ) -> SessionOpener {
        SessionOpener(processRunner: runner, appleScriptRunner: script, urlOpener: urlOpener, timeSource: FixedTimeSource(now: now))
    }

    private let terminalRunnerOutputs = [
        "/bin/ps -axo pid=,tty=,etime=,comm=": "30 ttys003 00:40 /usr/local/bin/claude\n",
        "/usr/sbin/lsof -a -p 30 -d cwd -Fn": "p30\nfcwd\nn/w/app\n",
        "/bin/ps -axo pid=,ppid=,comm=": "30 20 /usr/local/bin/claude\n20 1 /bin/zsh\n"
    ]

    // AC-14
    @Test func opensURLWhenSessionHasOne() throws {
        let url = try #require(URL(string: "codex://threads/t1"))
        let urlOpener = FakeURLOpener()
        let script = RecordingAppleScriptRunner { _ in true }
        let opened = makeOpener(script: script, urlOpener: urlOpener).open(session: makeSession(openURL: url, isTerminalSession: true))

        #expect(opened)
        #expect(urlOpener.openedURLs == [url])
        #expect(script.sources.isEmpty)
    }

    // AC-14
    @Test func focusesTerminalTabForTerminalSession() {
        let urlOpener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2"])
        let script = RecordingAppleScriptRunner { _ in true }
        let opener = makeOpener(runner: ScriptedProcessRunner(outputs: terminalRunnerOutputs), script: script, urlOpener: urlOpener)

        #expect(opener.open(session: makeSession(isTerminalSession: true)))
        #expect(script.sources.count == 1)
        #expect(script.sources[0].contains("/dev/ttys003"))
        #expect(urlOpener.openedURLs.isEmpty)
    }

    // AC-14
    @Test func returnsFalseWhenNothingToOpen() {
        let urlOpener = FakeURLOpener(runningBundleIdentifiers: ["com.googlecode.iterm2"])
        let opener = makeOpener(runner: ScriptedProcessRunner(outputs: terminalRunnerOutputs), urlOpener: urlOpener)

        #expect(!opener.open(session: makeSession(isTerminalSession: false)))
        #expect(!opener.open(session: makeSession(isTerminalSession: true, workingDirectory: nil)))
        #expect(!opener.open(session: makeSession(isTerminalSession: true, workingDirectory: "/w/other")))
    }
}
