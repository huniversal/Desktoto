import Boundaries
import Domain
import Foundation

/// 세션 줄을 눌렀을 때 그 세션이 있는 곳을 연다.
/// 데스크탑 앱의 대화는 링크로, 터미널(CLI) 세션은 그 세션이 도는 터미널 탭으로 이동한다.
/// 터미널 탭 이동은 AppleScript를 쓰므로 메인 스레드에서 호출한다(원본도 클릭 핸들러에서 호출했다).
public struct SessionOpener: Sendable {
    private let processScanner: TerminalProcessScanner
    private let tabFocuser: TerminalTabFocuser
    private let urlOpener: any URLOpener
    private let timeSource: any TimeSource

    public init(
        processRunner: any ProcessRunner,
        appleScriptRunner: any AppleScriptRunner,
        urlOpener: any URLOpener,
        timeSource: any TimeSource
    ) {
        processScanner = TerminalProcessScanner(processRunner: processRunner)
        tabFocuser = TerminalTabFocuser(processRunner: processRunner, appleScriptRunner: appleScriptRunner, urlOpener: urlOpener)
        self.urlOpener = urlOpener
        self.timeSource = timeSource
    }

    /// 찾아서 이동하면 true.
    public func open(session: SessionInfo) -> Bool {
        if let url = session.openURL { return urlOpener.open(url) }
        guard session.isTerminalSession, let workingDirectory = session.workingDirectory else { return false }
        let processes = processScanner.listProcesses(
            commandNames: [TerminalProcessMatcher.commandName(for: session.tool)],
            now: timeSource.now
        )
        guard let process = TerminalProcessMatcher.match(
            processes: processes,
            tool: session.tool,
            workingDirectory: workingDirectory,
            startedAt: session.startedAt
        ) else { return false }
        return tabFocuser.focus(process: process, sessionTitle: session.title)
    }
}
