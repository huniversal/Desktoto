import Foundation
import Testing
@testable import Desktoto

struct RefreshPolicyTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test func 주기가_원본과_같다() {
        #expect(RefreshPolicy.pollInterval == 1)
        #expect(RefreshPolicy.panelRefreshInterval == 2)
        #expect(RefreshPolicy.usagePreloadInterval == 30)
    }

    @Test func Codex_조회_간격은_패널이_열리면_30초_닫히면_300초다() {
        #expect(RefreshPolicy.codexLiveMinInterval(isPanelOpen: true) == 30)
        #expect(RefreshPolicy.codexLiveMinInterval(isPanelOpen: false) == 300)
    }

    @Test func 패널이_닫힌_동안_30초가_지나면_사용량을_미리_읽는다() {
        #expect(RefreshPolicy.shouldPreloadUsage(now: now, lastRefreshAt: now.addingTimeInterval(-30), isPanelOpen: false))
        #expect(!RefreshPolicy.shouldPreloadUsage(now: now, lastRefreshAt: now.addingTimeInterval(-29), isPanelOpen: false))
    }

    @Test func 패널이_열려_있으면_미리_읽지_않는다() {
        #expect(!RefreshPolicy.shouldPreloadUsage(now: now, lastRefreshAt: .distantPast, isPanelOpen: true))
    }

    @Test func 한_번도_읽지_않았으면_바로_미리_읽는다() {
        #expect(RefreshPolicy.shouldPreloadUsage(now: now, lastRefreshAt: .distantPast, isPanelOpen: false))
    }
}
