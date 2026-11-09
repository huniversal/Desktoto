import AppKit
import CoreGraphics
import Testing
@testable import MenuBarIcon

private let fast = IdleBehavior.fastSpeed + 1

// MARK: 표정 모양

@Test func blinkClosesEyesToOneRowAtTheGazedPosition() {
    let rects = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 2, vertical: 0), expression: .blink)

    #expect(rects.eyes == [UnitRect(7, 5, 2, 1), UnitRect(17, 5, 2, 1)])
    #expect(rects.mouth.isEmpty)
}

@Test func wideEyesAreOnlySlightlyTallerThanOpenEyes() {
    let open = CharacterGrid.rects(for: .standing)
    let wide = CharacterGrid.rects(for: .standing, expression: .wide)

    zip(open.eyes, wide.eyes).forEach { openEye, wideEye in
        #expect(wideEye.width == openEye.width)
        #expect(wideEye.height == openEye.height + 1)
    }
}

@Test func dizzyEyesAndBodyAlternateBetweenTwoPhases() {
    let first = CharacterGrid.rects(for: .standing, expression: .dizzy(phase: 0))
    let second = CharacterGrid.rects(for: .standing, expression: .dizzy(phase: 1))
    let wrapped = CharacterGrid.rects(for: .standing, expression: .dizzy(phase: 2))

    #expect(first.eyes[0].y != second.eyes[0].y)
    #expect(first.eyes[0].y == second.eyes[1].y)
    #expect(first.body.x == 3 - CharacterGrid.dizzyWobble)
    #expect(second.body.x == 3 + CharacterGrid.dizzyWobble)
    #expect(wrapped == first)
}

@Test func yawnClosesEyesAndOpensThenClosesTheMouth() {
    let heights = (0..<EyeExpression.yawnPhaseCount).map {
        CharacterGrid.rects(for: .standing, expression: .yawn(phase: $0)).mouth[0].height
    }

    // 입이 벌어졌다가 닫힌다.
    #expect(heights == [1, 2, 3, 3, 2, 1])
    #expect(CharacterGrid.rects(for: .standing, expression: .yawn(phase: 2)).eyes == CharacterGrid.closedEyeRects)
}

@Test func yawnLooksStraightAheadEvenWhenGazing() {
    let gazing = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 6, vertical: 4), expression: .yawn(phase: 1))
    let straight = CharacterGrid.rects(for: .standing, expression: .yawn(phase: 1))

    #expect(gazing == straight)
}

@Test func expressionsStayInsideTheBodyForEveryDirection() {
    let expressions: [EyeExpression] = [.blink, .wide, .dizzy(phase: 0), .dizzy(phase: 1)]
        + (0..<EyeExpression.yawnPhaseCount).map { .yawn(phase: $0) }

    expressions.forEach { expression in
        (0..<GazeDirection.count).forEach { index in
            let rects = CharacterGrid.rects(for: .standing, gaze: GazeDirection(index: index), expression: expression)
            (rects.eyes + rects.mouth).forEach { part in
                #expect(part.x >= rects.body.x && part.x + part.width <= rects.body.x + rects.body.width)
                #expect(part.y >= rects.body.y && part.y + part.height <= rects.body.y + rects.body.height)
            }
        }
    }
}

@Test func runningAndSleepingIgnoreExpressions() {
    #expect(CharacterGrid.rects(for: .runningA, expression: .wide) == CharacterGrid.rects(for: .runningA))
    #expect(CharacterGrid.rects(for: .sleeping, expression: .yawn(phase: 2)) == CharacterGrid.rects(for: .sleeping))
}

// MARK: 표정을 정하는 규칙

@Test func calmMouseKeepsEyesOpenBetweenBlinks() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 4)

    #expect(behavior.tick(now: 1, nextBlinkDelay: 4) == .open)
    #expect(behavior.tick(now: 3.9, nextBlinkDelay: 4) == .open)
}

@Test func blinkLastsBrieflyThenSchedulesTheNextOne() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 4)

    #expect(behavior.tick(now: 4, nextBlinkDelay: 5) == .blink)
    #expect(behavior.tick(now: 4 + IdleBehavior.blinkDuration / 2, nextBlinkDelay: 5) == .blink)
    #expect(behavior.tick(now: 4 + IdleBehavior.blinkDuration + 0.01, nextBlinkDelay: 5) == .open)
    #expect(behavior.tick(now: 8.9, nextBlinkDelay: 5) == .open)
    #expect(behavior.tick(now: 9, nextBlinkDelay: 5) == .blink)
}

@Test func fastMouseMakesEyesWideThenReturnsToNormal() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 100)
    behavior.mouseMoved(speed: fast, now: 1)

    #expect(behavior.tick(now: 1.1, nextBlinkDelay: 100) == .wide)
    #expect(behavior.tick(now: 1 + IdleBehavior.wideHold + 0.01, nextBlinkDelay: 100) == .open)
}

@Test func slowMouseNeverStartles() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 100)
    (1...50).forEach { behavior.mouseMoved(speed: IdleBehavior.fastSpeed - 1, now: Double($0) * 0.05) }

    #expect(behavior.tick(now: 2.6, nextBlinkDelay: 100) == .open)
}

@Test func keepingTheMouseFastMakesTheCharacterDizzy() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 100)
    var now = 0.0
    while now < IdleBehavior.dizzyAfter + 0.5 {
        now += 0.05
        behavior.mouseMoved(speed: fast, now: now)
    }

    guard case .dizzy = behavior.tick(now: now, nextBlinkDelay: 100) else {
        Issue.record("어지러워야 한다")
        return
    }
    // 빠른 움직임이 멈춰도 한동안 어지럽다가, 지나면 돌아온다.
    guard case .dizzy = behavior.tick(now: now + IdleBehavior.dizzyHold - 0.1, nextBlinkDelay: 100) else {
        Issue.record("아직 어지러워야 한다")
        return
    }
    #expect(behavior.tick(now: now + IdleBehavior.dizzyHold + 0.1, nextBlinkDelay: 100) == .open)
}

@Test func dizzyPhasesAlternate() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 100)
    var now = 0.0
    while now < IdleBehavior.dizzyAfter + 0.1 {
        now += 0.05
        behavior.mouseMoved(speed: fast, now: now)
    }
    behavior.tick(now: now, nextBlinkDelay: 100)
    let later = now + IdleBehavior.dizzyStepInterval + 0.01

    #expect(behavior.tick(now: now, nextBlinkDelay: 100) != behavior.tick(now: later, nextBlinkDelay: 100))
}

@Test func briefFastBurstsDoNotAddUpToDizziness() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 100)
    // 빠르게 한 번 움직이고 오래 쉬기를 반복하면 어지러움이 쌓이지 않는다. 빠르게 움직인 시간이 모두 2초(1.5초 초과)여도 마찬가지다.
    (0..<20).forEach { round in
        let start = Double(round) * 3
        behavior.mouseMoved(speed: fast, now: start)
        behavior.mouseMoved(speed: fast, now: start + 0.1)
        // 움직이는 동안에도 어지럽지 않다.
        #expect(behavior.tick(now: start + 0.1, nextBlinkDelay: 100) != .dizzy(phase: 0))
        #expect(behavior.tick(now: start + 0.1, nextBlinkDelay: 100) != .dizzy(phase: 1))
        behavior.tick(now: start + 2, nextBlinkDelay: 100)
    }

    #expect(behavior.tick(now: 80, nextBlinkDelay: 100) != .dizzy(phase: 0))
    #expect(behavior.tick(now: 80, nextBlinkDelay: 100) != .dizzy(phase: 1))
}

@Test func leavingTheMouseAloneMakesTheCharacterYawnOnce() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 1000)
    behavior.mouseMoved(speed: 0, now: 0)

    #expect(behavior.tick(now: IdleBehavior.yawnAfter - 1, nextBlinkDelay: 1000) == .open)
    #expect(behavior.tick(now: IdleBehavior.yawnAfter, nextBlinkDelay: 1000) == .yawn(phase: 0))
    #expect(behavior.tick(now: IdleBehavior.yawnAfter + IdleBehavior.yawnStepInterval * 2.1, nextBlinkDelay: 1000) == .yawn(phase: 2))

    let end = IdleBehavior.yawnAfter + IdleBehavior.yawnStepInterval * Double(EyeExpression.yawnPhaseCount) + 0.1
    #expect(behavior.tick(now: end, nextBlinkDelay: 1000) == .open)
    // 마우스가 움직이기 전에는 다시 하품하지 않는다.
    #expect(behavior.tick(now: end + 60, nextBlinkDelay: 1000) == .open)

    behavior.mouseMoved(speed: 0, now: end + 61)
    #expect(behavior.tick(now: end + 61 + IdleBehavior.yawnAfter, nextBlinkDelay: 1000) == .yawn(phase: 0))
}

@Test func movingTheMouseInterruptsAYawn() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 1000)
    behavior.tick(now: IdleBehavior.yawnAfter + 0.3, nextBlinkDelay: 1000)

    behavior.mouseMoved(speed: 100, now: IdleBehavior.yawnAfter + 0.4)

    #expect(behavior.tick(now: IdleBehavior.yawnAfter + 0.45, nextBlinkDelay: 1000) == .open)
}

@Test func blinkWaitsUntilAfterAnotherExpressionEnds() {
    var behavior = IdleBehavior(now: 0, blinkDelay: 1)
    behavior.mouseMoved(speed: fast, now: 1)

    #expect(behavior.tick(now: 1.1, nextBlinkDelay: 4) == .wide)
    // 놀람이 끝난 직후에는 바로 깜빡이지 않는다.
    #expect(behavior.tick(now: 1 + IdleBehavior.wideHold + 0.05, nextBlinkDelay: 4) == .open)
}

// MARK: 이미지

@MainActor @Test func expressionImagesAreDrawnLazilyAndCached() {
    var builtCount = 0
    let imageSet = IconImageSet(appearance: IconAppearance(), scale: 2, pointHeight: 20) { _, _ in
        builtCount += 1
        return NSImage(size: NSSize(width: 1, height: 1))
    }
    let before = builtCount

    let first = imageSet.image(for: .expression(.blink, .center))
    #expect(builtCount == before + 1)
    #expect(imageSet.image(for: .expression(.blink, .center)) === first)
    #expect(builtCount == before + 1)

    // 평소 표정은 미리 그려 둔 시선 이미지를 쓴다.
    #expect(imageSet.image(for: .expression(.open, .center)) === imageSet.image(for: .standing))
    #expect(builtCount == before + 1)

    // 모습이 바뀌면 캐시를 비운다.
    imageSet.update(appearance: IconAppearance(colorMode: .color))
    let rebuilt = builtCount
    _ = imageSet.image(for: .expression(.blink, .center))
    #expect(builtCount == rebuilt + 1)
}

// MARK: 어지러울 때의 별

@Test func dizzyAddsSparksBehindTheCharacterOnlyWhileDizzy() {
    let appearance = IconAppearance()
    let plain = IconScene.pieces(frame: .expression(.open, .center), appearance: appearance)
    let dizzy = IconScene.pieces(frame: .expression(.dizzy(phase: 0), .center), appearance: appearance)

    let sparks = dizzy.filter { $0.color == IconPalette.dizzySpark }
    #expect(!sparks.isEmpty)
    #expect(plain.allSatisfy { $0.color != IconPalette.dizzySpark })
    // 별은 캐릭터보다 먼저 그려서 뒤에 깔린다.
    #expect(dizzy.prefix(sparks.count).allSatisfy { $0.color == IconPalette.dizzySpark })
}

@Test func sparksAlternateBetweenPhases() {
    #expect(DizzySparks.rects(phase: 0) != DizzySparks.rects(phase: 1))
    #expect(DizzySparks.rects(phase: 2) == DizzySparks.rects(phase: 0))
}

@Test func sparksStayInsideTheCanvasAndOutOfTheCharacterAndBadge() {
    let characterLeft = CharacterGrid.standingOriginX - 1 - CharacterGrid.dizzyWobble
    let characterRight = CharacterGrid.standingOriginX + CharacterGrid.characterWidth + 1 + CharacterGrid.dizzyWobble
    let badgeLeft = BadgeGrid.originX(characterOriginX: CharacterGrid.standingOriginX)

    (0..<DizzySparks.phaseCount).forEach { phase in
        DizzySparks.rects(phase: phase).forEach { rect in
            #expect(rect.x >= 0 && rect.x + rect.width <= CharacterGrid.canvasWidth)
            #expect(rect.y >= 0 && rect.y + rect.height <= CharacterGrid.canvasHeight)
            // 캐릭터 몸과 팔이 차지하는 가로 범위 밖에 있다.
            #expect(rect.x + rect.width <= characterLeft || rect.x >= characterRight)
            // 오른쪽 위의 배지 자리(위 7칸)를 피한다.
            if rect.x + rect.width > badgeLeft {
                #expect(rect.y >= 7)
            }
        }
    }
}
