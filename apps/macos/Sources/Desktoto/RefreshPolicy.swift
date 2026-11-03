import Foundation

/// 감시 결과를 읽고 갱신하는 주기. 타이머를 만드는 일은 앱이 한다.
enum RefreshPolicy {
    static let pollInterval: TimeInterval = 1
    /// 패널이 열려 있는 동안 값을 갱신하는 간격
    static let panelRefreshInterval: TimeInterval = 2
    /// 패널이 닫혀 있는 동안 사용량을 미리 읽어 두는 간격. 처음 열 때 패널 높이가 바로 맞도록 채워 두는 용도다.
    static let usagePreloadInterval: TimeInterval = 30
    static let codexLiveOpenInterval: TimeInterval = 30
    static let codexLiveClosedInterval: TimeInterval = 300

    static func codexLiveMinInterval(isPanelOpen: Bool) -> TimeInterval {
        isPanelOpen ? codexLiveOpenInterval : codexLiveClosedInterval
    }

    static func shouldPreloadUsage(now: Date, lastRefreshAt: Date, isPanelOpen: Bool) -> Bool {
        !isPanelOpen && now.timeIntervalSince(lastRefreshAt) >= usagePreloadInterval
    }
}
