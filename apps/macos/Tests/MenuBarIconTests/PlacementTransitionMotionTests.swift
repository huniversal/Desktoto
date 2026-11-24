import CoreGraphics
import Testing
@testable import MenuBarIcon

// 노치 오른쪽 봇 자리(가운데 100, 19)와 메뉴바 토토 자리(가운데 300, 19) 사이 전환
private func makeMotion(_ direction: PlacementTransitionMotion.Direction) -> PlacementTransitionMotion {
    PlacementTransitionMotion(
        direction: direction,
        start: CGPoint(x: 100, y: 19),
        end: CGPoint(x: 300, y: 19),
        startSize: 24,
        endSize: 34,
        botWidth: 26,
        duration: 3
    )
}

@Test func detachStartsAttachedToTheNotchAndEndsAsAToto() {
    let motion = makeMotion(.toMenuBar)
    let first = motion.frame(at: 0)
    let last = motion.frame(at: 3)

    #expect(first.center == motion.start)
    #expect(first.attachedWidth == motion.botWidth)
    #expect(last.center == motion.end)
    #expect(last.size == motion.endSize)
    #expect(last.attachedWidth == 0)
    // 메뉴바에 앉으면 물방울이 만두 모양으로 바뀌어 있다.
    #expect(last.triangle > 0.99)
}

@Test func attachStartsAsATotoAndEndsFilledIntoTheBotSpot() {
    let motion = makeMotion(.toNotch)
    let first = motion.frame(at: 0)
    let last = motion.frame(at: 3)

    #expect(first.center == motion.end)
    #expect(first.triangle == 1)
    #expect(first.attachedWidth == 0)
    // 끝에서는 정확히 봇 자리에 멈추고 봇 몸이 다 채워져서 노치 봇과 이어진다.
    #expect(last.center == motion.start)
    #expect(last.attachedWidth == motion.botWidth)
    #expect(last.scaleX == 1 && last.scaleY == 1)
}

@Test func outOfRangeTimesClampToTheFirstAndLastFrames() {
    let motion = makeMotion(.toMenuBar)
    #expect(motion.frame(at: -1) == motion.frame(at: 0))
    #expect(motion.frame(at: 10) == motion.frame(at: 3))
}

@Test func attachDoesNotReachOutBeforeTheDropTouchesTheNotch() {
    // 물방울이 튀어 오는 동안에는 노치 폭이 그대로다(노치가 먼저 마중 나가지 않는다).
    let motion = makeMotion(.toNotch)
    for step in 0...10 {
        let frame = motion.frame(at: Double(step) * 0.1)
        #expect(frame.attachedWidth == 0, "t=\(Double(step) * 0.1)")
    }
}

@Test func dropStaysWithinTheMenuBarBandWhileHopping() {
    // 통통 튈 때 메뉴바(높이 38) 밖으로 크게 벗어나지 않는다.
    for direction in [PlacementTransitionMotion.Direction.toMenuBar, .toNotch] {
        let motion = makeMotion(direction)
        for step in 0...60 {
            let frame = motion.frame(at: Double(step) * 0.05)
            #expect(frame.center.y >= 19 - 10 && frame.center.y <= 19 + 3, "\(direction) t=\(Double(step) * 0.05)")
            #expect(frame.attachedWidth >= 0 && frame.attachedWidth <= motion.botWidth)
        }
    }
}

@Test func detachHasNoJumpWhereTheCrouchHandsOverToTheTug() {
    // 웅크리기 끝(진행 8%)과 버티기 시작이 같은 모습이라 크기와 위치가 끊기지 않는다.
    let motion = makeMotion(.toMenuBar)
    let boundary = 0.08 * motion.duration
    let before = motion.frame(at: boundary - 0.001)
    let after = motion.frame(at: boundary + 0.001)
    #expect(abs(before.size - after.size) < 0.2)
    #expect(abs(before.center.x - after.center.x) < 0.2)
    #expect(abs(before.scaleX - after.scaleX) < 0.02)
}
