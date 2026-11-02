import Boundaries
import Foundation

// CLI 프로세스가 돌고 있는 터미널 탭을 앞으로 가져온다. iTerm2와 Terminal.app은 tty로, Orca는 CLI와 워크트리 폴더로 찾는다.
// 다른 터미널은 지원하지 않는다(원본 동작).
public struct TerminalTabFocuser: Sendable {
    private struct TerminalApp {
        let bundleIdentifier: String
        let makeScript: @Sendable (_ tty: String) -> String
    }

    private static let terminalApps = [
        TerminalApp(bundleIdentifier: "com.googlecode.iterm2", makeScript: { TerminalScripts.makeITermScript(tty: $0) }),
        TerminalApp(bundleIdentifier: "com.apple.Terminal", makeScript: { TerminalScripts.makeTerminalScript(tty: $0) })
    ]
    private static let orcaAppName = "Orca.app"
    private static let orcaBundleIdentifier = "com.stablyai.orca"
    private static let orcaCLIRelativePath = "Contents/Resources/bin/orca"

    private let processRunner: any ProcessRunner
    private let appleScriptRunner: any AppleScriptRunner
    private let urlOpener: any URLOpener

    public init(processRunner: any ProcessRunner, appleScriptRunner: any AppleScriptRunner, urlOpener: any URLOpener) {
        self.processRunner = processRunner
        self.appleScriptRunner = appleScriptRunner
        self.urlOpener = urlOpener
    }

    // process가 있는 탭을 앞으로 가져온다. 찾아서 이동하면 true. sessionTitle은 Orca에서 같은 워크트리의 탭이 여럿일 때 쓴다.
    public func focus(process: TerminalProcess, sessionTitle: String?) -> Bool {
        if let orcaAppPath = findOrcaAppPath(of: process.pid) {
            return focusOrcaTerminal(process: process, sessionTitle: sessionTitle, orcaAppPath: orcaAppPath)
        }
        let ttyPath = "/dev/\(process.tty)"

        // 실행 중인 터미널 앱에만 요청해서, 꺼져 있는 앱이 AppleScript 때문에 실행되지 않게 한다.
        for app in Self.terminalApps where urlOpener.isRunning(bundleIdentifier: app.bundleIdentifier) {
            if (try? appleScriptRunner.runReturningBoolean(source: app.makeScript(ttyPath))) == true { return true }
        }
        return false
    }

    // Orca는 탭의 tty를 알려 주지 않아서, 탭이 속한 워크트리 폴더로 프로세스의 작업 폴더를 맞춘다.
    private func focusOrcaTerminal(process: TerminalProcess, sessionTitle: String?, orcaAppPath: String) -> Bool {
        guard let workingDirectory = process.workingDirectory else { return false }
        let cliPath = "\(orcaAppPath)/\(Self.orcaCLIRelativePath)"
        guard let listOutput = try? processRunner.run(executable: cliPath, arguments: ["terminal", "list", "--json"]),
              let handle = OrcaTerminalSelector.pickHandle(
                terminals: OrcaTerminalSelector.parseTerminals(Data(listOutput.utf8)),
                workingDirectory: workingDirectory,
                sessionTitle: sessionTitle
              ),
              let switchOutput = try? processRunner.run(
                executable: cliPath,
                arguments: ["terminal", "switch", "--terminal", handle, "--json"]
              ),
              OrcaTerminalSelector.hasSucceeded(Data(switchOutput.utf8)) else { return false }
        urlOpener.activate(bundleIdentifier: Self.orcaBundleIdentifier)
        return true
    }

    // 프로세스의 조상 중에 Orca 앱이 있으면 그 앱 경로(…/Orca.app)를, 없으면 nil.
    private func findOrcaAppPath(of pid: Int) -> String? {
        guard let output = try? processRunner.run(executable: "/bin/ps", arguments: ["-axo", "pid=,ppid=,comm="]) else {
            return nil
        }
        return ProcessListParser.findAncestorAppPath(
            of: pid,
            appName: Self.orcaAppName,
            in: ProcessListParser.parseProcessTree(output)
        )
    }
}
