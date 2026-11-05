import Boundaries
import Foundation

// CLI 프로세스가 돌고 있는 터미널 탭을 앞으로 가져온다. iTerm2와 Terminal.app은 tty로, Orca는 CLI와 워크트리 폴더로,
// cmux는 프로세스 환경의 패널 UUID와 cmux CLI로 찾는다. IDE(VS Code, Antigravity IDE)의 통합 터미널은 탭을 지정할 수 없어 IDE 앱만 앞으로 가져온다.
// 다른 터미널은 지원하지 않는다.
public struct TerminalTabFocuser: Sendable {
    private struct TerminalApp {
        let bundleIdentifier: String
        let makeScript: @Sendable (_ tty: String) -> String
    }

    private static let terminalApps = [
        TerminalApp(bundleIdentifier: "com.googlecode.iterm2", makeScript: { TerminalScripts.makeITermScript(tty: $0) }),
        TerminalApp(bundleIdentifier: "com.apple.Terminal", makeScript: { TerminalScripts.makeTerminalScript(tty: $0) })
    ]
    // 통합 터미널을 가진 IDE. 외부에서 창이나 터미널 탭을 지정할 방법이 없어서 앱 단위로만 앞으로 가져온다.
    private struct IDEApp {
        let appName: String
        let bundleIdentifier: String
    }

    private static let ideApps = [
        IDEApp(appName: "Visual Studio Code.app", bundleIdentifier: "com.microsoft.VSCode"),
        IDEApp(appName: "Antigravity IDE.app", bundleIdentifier: "com.google.antigravity-ide")
    ]
    private static let orcaAppName = "Orca.app"
    private static let orcaBundleIdentifier = "com.stablyai.orca"
    private static let orcaCLIRelativePath = "Contents/Resources/bin/orca"
    private static let cmuxAppName = "cmux.app"
    private static let cmuxBundleIdentifier = "com.cmuxterm.app"
    private static let cmuxCLIRelativePath = "Contents/Resources/bin/cmux"

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
        let processTree = loadProcessTree()
        if let orcaAppPath = findAncestorAppPath(of: process.pid, appName: Self.orcaAppName, in: processTree) {
            return focusOrcaTerminal(process: process, sessionTitle: sessionTitle, orcaAppPath: orcaAppPath)
        }
        if let cmuxAppPath = findAncestorAppPath(of: process.pid, appName: Self.cmuxAppName, in: processTree) {
            return focusCmuxTerminal(process: process, cmuxAppPath: cmuxAppPath)
        }
        if let ideApp = Self.ideApps.first(where: {
            findAncestorAppPath(of: process.pid, appName: $0.appName, in: processTree) != nil
        }) {
            urlOpener.activate(bundleIdentifier: ideApp.bundleIdentifier)
            return true
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

    // cmux는 탭의 tty나 작업 폴더 대신, 터미널 안 프로세스의 환경에 패널 UUID(CMUX_SURFACE_ID)를 넣어 준다.
    // 그 UUID로 패널을 직접 지정하므로 같은 폴더에 세션이 여럿이어도 정확하다.
    // 소켓 제어 모드가 "cmux 프로세스만"(기본값)이면 cmux CLI가 거부되어 출력이 비고, 이때는 이동하지 못한 것으로 본다.
    private func focusCmuxTerminal(process: TerminalProcess, cmuxAppPath: String) -> Bool {
        guard let environmentOutput = try? processRunner.run(executable: "/bin/ps", arguments: ["eww", "-p", "\(process.pid)"]),
              let surfaceID = CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: environmentOutput),
              let focusOutput = try? processRunner.run(
                executable: "\(cmuxAppPath)/\(Self.cmuxCLIRelativePath)",
                arguments: ["focus-panel", "--panel", surfaceID]
              ),
              CmuxTerminalSelector.hasSucceeded(focusOutput) else { return false }
        urlOpener.activate(bundleIdentifier: Self.cmuxBundleIdentifier)
        return true
    }

    // 전체 프로세스의 부모 관계와 실행 파일 경로. ps를 실행하지 못하면 빈 트리다.
    private func loadProcessTree() -> ProcessListParser.ProcessTree {
        guard let output = try? processRunner.run(executable: "/bin/ps", arguments: ["-axo", "pid=,ppid=,comm="]) else {
            return ProcessListParser.ProcessTree()
        }
        return ProcessListParser.parseProcessTree(output)
    }

    // 프로세스의 조상 중에 appName 앱이 있으면 그 앱 경로(…/Orca.app)를, 없으면 nil.
    private func findAncestorAppPath(of pid: Int, appName: String, in tree: ProcessListParser.ProcessTree) -> String? {
        ProcessListParser.findAncestorAppPath(of: pid, appName: appName, in: tree)
    }
}
