import Foundation

/// Claude 세션을 데스크탑 앱에서 여는 링크를 묻는다. `SessionMonitoring`이 주입받고 `TerminalIntegration`이 구현한다.
public protocol SessionLinkResolver: Sendable {
    /// 기록 파일의 세션 id에 대응하는 앱 링크. 데스크탑 앱의 세션이 아니거나 찾지 못하면 nil이다.
    func url(forSessionID sessionID: String) -> URL?
}
