import Domain
import Foundation
import Testing
@testable import SessionPanel

struct PanelTextTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    // AC-1
    @Test func tokenCountMatchesOriginalAtBoundaries() {
        #expect(PanelText.tokenCount(0) == "0")
        #expect(PanelText.tokenCount(999) == "999")
        #expect(PanelText.tokenCount(1000) == "1K")
        #expect(PanelText.tokenCount(1500) == "1K")
        #expect(PanelText.tokenCount(1999) == "1K")
        #expect(PanelText.tokenCount(200_000) == "200K")
        #expect(PanelText.tokenCount(999_999) == "999K")
        #expect(PanelText.tokenCount(1_000_000) == "1M")
        #expect(PanelText.tokenCount(1_500_000) == "1.5M")
        #expect(PanelText.tokenCount(2_000_000) == "2M")
    }

    // AC-2
    @Test func usageRatioNeedsBothTokensAndPositiveWindow() {
        #expect(PanelText.usageRatio(of: makeSession(usedTokens: 50, windowTokens: 200)) == 0.25)
        #expect(PanelText.usageRatio(of: makeSession(usedTokens: 300, windowTokens: 200)) == 1)
        #expect(PanelText.usageRatio(of: makeSession(usedTokens: 50, windowTokens: 0)) == nil)
        #expect(PanelText.usageRatio(of: makeSession(usedTokens: nil, windowTokens: 200)) == nil)
        #expect(PanelText.usageRatio(of: makeSession(usedTokens: 50, windowTokens: nil)) == nil)
    }

    // AC-2
    @Test func trailingTextShowsRoundedPercentDashOrEstimate() {
        #expect(PanelText.trailing(of: makeSession(usedTokens: 421, windowTokens: 1000)) == "42%")
        #expect(PanelText.trailing(of: makeSession(usedTokens: 425, windowTokens: 1000)) == "43%")
        #expect(PanelText.trailing(of: makeSession(usedTokens: 421, windowTokens: 1000, isWindowEstimated: true)) == "~42%")
        #expect(PanelText.trailing(of: makeSession()) == "-")
    }

    // AC-2
    @Test func tokenUsageTextMarksEstimatedWindowOnly() {
        #expect(PanelText.tokenUsage(of: makeSession(usedTokens: 84_000, windowTokens: 200_000)) == "84K / 200K")
        #expect(PanelText.tokenUsage(of: makeSession(usedTokens: 84_000, windowTokens: 1_000_000, isWindowEstimated: true)) == "84K / ~1M")
        #expect(PanelText.tokenUsage(of: makeSession(usedTokens: 84_000)) == "-")
        #expect(PanelText.tokenUsage(of: makeSession(windowTokens: 200_000)) == "-")
    }

    // AC-2
    @Test func titleAndModelNameFallBack() {
        #expect(PanelText.title(of: makeSession(projectName: "desktoto", title: "작업 제목")) == "작업 제목")
        #expect(PanelText.title(of: makeSession(projectName: "desktoto")) == "desktoto")
        #expect(PanelText.modelName(of: makeSession(modelName: "opus")) == "opus")
        #expect(PanelText.modelName(of: makeSession()) == "모델 알 수 없음")
    }

    // AC-3
    @Test func resetRemainingUsesMinutesHoursOrDays() {
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(30 * 60), now: now) == "30분")
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(90 * 60), now: now) == "1시간 30분")
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(60 * 60), now: now) == "1시간 0분")
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval((25 * 60 + 5) * 60), now: now) == "1일 1시간")
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(24 * 3600), now: now) == "1일 0시간")
    }

    // AC-3
    @Test func resetRemainingTruncatesToMinutesAndClampsPastToZero() {
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(59), now: now) == "0분")
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(119), now: now) == "1분")
        #expect(PanelText.resetRemaining(until: now.addingTimeInterval(-600), now: now) == "0분")
        #expect(PanelText.resetRemaining(until: nil, now: now) == "")
    }

    @Test func percentRoundsToWholeNumber() {
        #expect(PanelText.percent(0) == "0%")
        #expect(PanelText.percent(0.426) == "43%")
        #expect(PanelText.percent(1) == "100%")
    }

    // AC-4
    @Test func waitingPillTextFollowsWaitingKind() {
        #expect(PanelText.waitingPill(.approval) == "승인 필요")
        #expect(PanelText.waitingPill(.question) == "답변 필요")
    }
}
