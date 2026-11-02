import CoreGraphics
import Testing
@testable import SessionPanel

// 그림자 여백 36, 아이콘 아래 간격 6, 화면 가장자리 간격 8은 원본 값이다.
struct PanelFrameTests {
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 342, height: 200)

    // AC-5
    @Test func alignsGlassLeftEdgeToStatusItemAndPlacesBelowIt() {
        let buttonFrame = CGRect(x: 100, y: 1000, width: 24, height: 24)
        let origin = PanelFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        #expect(origin == CGPoint(x: 64, y: 830))
    }

    // AC-5
    @Test func keepsGlassInsideLeftScreenEdge() {
        let buttonFrame = CGRect(x: 0, y: 1000, width: 24, height: 24)
        let origin = PanelFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        #expect(origin.x == -28)
    }

    // AC-5
    @Test func keepsGlassInsideRightScreenEdge() {
        let buttonFrame = CGRect(x: 1400, y: 1000, width: 24, height: 24)
        let origin = PanelFrame.origin(buttonFrame: buttonFrame, visibleFrame: visibleFrame, size: size)

        #expect(origin.x == 1126)
    }

    // AC-5
    @Test func prefersLeftLimitWhenScreenIsNarrowerThanPanel() {
        let narrow = CGRect(x: 0, y: 0, width: 250, height: 900)
        let buttonFrame = CGRect(x: 100, y: 1000, width: 24, height: 24)
        let origin = PanelFrame.origin(buttonFrame: buttonFrame, visibleFrame: narrow, size: size)

        #expect(origin.x == -28)
    }

    // AC-5
    @Test func respectsVisibleFrameOffsetOfSecondaryScreen() {
        let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let buttonFrame = CGRect(x: 1440, y: 1080, width: 24, height: 24)
        let origin = PanelFrame.origin(buttonFrame: buttonFrame, visibleFrame: secondary, size: size)

        #expect(origin.x == 1412)
    }
}
