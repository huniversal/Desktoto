import CoreGraphics
import Testing
@testable import Feedback

// 아이콘 아래 간격 6, 화면 가장자리 간격 8은 세션 패널과 같은 값이다.
struct FeedbackWindowFrameTests {
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 360, height: 268)

    // 오른쪽으로 펼쳐지는 위치
    @Test func alignsLeftEdgeToStatusItemAndPlacesBelowIt() {
        let buttonFrame = CGRect(x: 900, y: 1000, width: 24, height: 24)

        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        #expect(origin == CGPoint(x: 900, y: 726))
    }

    @Test func expandsToTheRightOfTheIcon() {
        let buttonFrame = CGRect(x: 600, y: 1000, width: 24, height: 24)

        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        #expect(origin.x == buttonFrame.minX)
        #expect(origin.x + size.width > buttonFrame.maxX)
    }

    @Test func keepsInsideRightScreenEdge() {
        let buttonFrame = CGRect(x: 1400, y: 1000, width: 24, height: 24)

        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        let expectedX: CGFloat = 1440 - 360 - 8
        #expect(origin.x == expectedX)
    }

    @Test func keepsInsideLeftScreenEdge() {
        let buttonFrame = CGRect(x: 0, y: 1000, width: 24, height: 24)

        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        #expect(origin.x == 8)
    }

    @Test func prefersLeftLimitWhenScreenIsNarrowerThanWindow() {
        let narrow = CGRect(x: 0, y: 0, width: 300, height: 900)
        let buttonFrame = CGRect(x: 100, y: 1000, width: 24, height: 24)

        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonFrame, visibleFrame: narrow, size: size)

        #expect(origin.x == 8)
    }

    @Test func respectsVisibleFrameOriginOnSecondaryDisplay() {
        let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let buttonFrame = CGRect(x: 3300, y: 1100, width: 24, height: 24)

        let origin = FeedbackWindowFrame.origin(buttonFrame: buttonFrame, visibleFrame: secondary, size: size)

        let expectedX: CGFloat = 1440 + 1920 - 360 - 8
        #expect(origin.x == expectedX)
    }
}
