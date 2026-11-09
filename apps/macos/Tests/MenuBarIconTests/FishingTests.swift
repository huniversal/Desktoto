import CoreGraphics
import Foundation
import Testing
@testable import MenuBarIcon

private func middle() -> Double { 0.5 }

/// seconds초 동안 1/60초씩 진행한다.
private func run(_ session: inout FishingSession, seconds: TimeInterval, random: () -> Double = middle) {
    var left = seconds
    while left > 0 {
        session.update(deltaTime: 1.0 / 60, random: random)
        left -= 1.0 / 60
    }
}

// MARK: 낚시의 흐름

@Test func sessionStartsWaitingWithClosedEyes() {
    let session = FishingSession()

    #expect(session.phase == .waiting)
    #expect(session.eyes == .closed)
    #expect(session.rodPose == .rest)
    #expect(session.lineLength == FishingSession.restLineLength)
    #expect(!session.hasFish)
    #expect(session.caughtCount == 0)
}

@Test func biteComesAfterTheFirstWait() {
    var session = FishingSession()

    run(&session, seconds: FishingSession.firstWait - 0.2)
    #expect(session.phase == .waiting)

    run(&session, seconds: 0.4)
    #expect(session.phase == .biting)
    #expect(session.isBubbleVisible)
    #expect(session.eyes == .open)
}

@Test func rodShakesBetweenUpAndDownWhileBiting() {
    var session = FishingSession()
    run(&session, seconds: FishingSession.firstWait + 0.05)
    #expect(session.phase == .biting)

    var poses = Set<RodPose>()
    (0..<40).forEach { _ in
        session.update(deltaTime: 1.0 / 60, random: middle)
        if session.phase == .biting { poses.insert(session.rodPose) }
    }

    #expect(poses == [.up, .down])
}

@Test func theLineWigglesOnlyWhileBiting() {
    var session = FishingSession()
    #expect(session.lineWiggle == 0)

    run(&session, seconds: FishingSession.firstWait + 0.05)
    var wiggles = Set<CGFloat>()
    (0..<30).forEach { _ in
        session.update(deltaTime: 1.0 / 60, random: middle)
        if session.phase == .biting { wiggles.insert(session.lineWiggle) }
    }
    #expect(wiggles == [0, 1])
}

@Test func everyBiteEndsInACatchBecauseThereIsNoFailure() {
    var session = FishingSession()

    run(&session, seconds: FishingSession.firstWait + FishingSession.biteDuration + 0.1)

    #expect(session.phase == .reeling)
    #expect(session.hasFish)
    #expect(session.eyes == .wide)
    #expect(session.rodPose == .bent)
    #expect(session.caughtCount == 0)

    run(&session, seconds: FishingSession.reelDuration)
    #expect(session.phase == .showing)
    #expect(session.caughtCount == 1)
}

@Test func lineShortensWhileReelingAndStaysShortWhileShowing() {
    var session = FishingSession()
    run(&session, seconds: FishingSession.firstWait + FishingSession.biteDuration + 0.05)
    let startLength = session.lineLength

    run(&session, seconds: FishingSession.reelDuration * 0.6)
    #expect(session.lineLength < startLength)
    #expect(session.lineLength > FishingSession.reeledLineLength)

    run(&session, seconds: FishingSession.reelDuration)
    #expect(session.phase == .showing)
    #expect(session.lineLength == FishingSession.reeledLineLength)
}

@Test func afterShowingTheFishGoesAndWaitingStartsAgain() {
    var session = FishingSession()
    run(&session, seconds: FishingSession.firstWait + FishingSession.biteDuration + FishingSession.reelDuration + FishingSession.showDuration + 0.1)

    #expect(session.phase == .waiting)
    #expect(!session.hasFish)
    #expect(session.lineLength == FishingSession.restLineLength)
    #expect(session.caughtCount == 1)
}

@Test func nextWaitStaysInsideTheRangeForAnyRandom() {
    [0.0, 0.5, 1.0, -3.0, 9.0].forEach { value in
        var session = FishingSession()
        run(&session, seconds: FishingSession.firstWait + FishingSession.biteDuration + FishingSession.reelDuration + FishingSession.showDuration + 0.1, random: { value })

        #expect(FishingSession.waitRange.contains(session.waitDuration))
    }
}

@Test func aHugeTimeStepStillAdvancesThroughManyCycles() {
    var session = FishingSession()

    session.update(deltaTime: 600, random: middle)

    #expect(session.caughtCount > 5)
}

@Test func nothingChangesWithoutTimePassing() {
    var session = FishingSession()
    session.update(deltaTime: 0, random: middle)
    session.update(deltaTime: -1, random: middle)

    #expect(session.elapsed == 0)
    #expect(session.phase == .waiting)
}

@Test func legsSwingBackAndForthSlowly() {
    var session = FishingSession()
    let first = session.legSwing

    run(&session, seconds: 1.5)
    #expect(session.legSwing != first)

    run(&session, seconds: 1.4)
    #expect(session.legSwing == first)
}

@Test func frameFollowsTheSessionAndRepeatsWhileNothingChanges() {
    var session = FishingSession()
    let first = session.frame

    session.update(deltaTime: 0.1, random: middle)

    #expect(session.frame == first)
    #expect(first.lineLength == Int(FishingSession.restLineLength))
}

// MARK: 메뉴바 이미지 목록

/// 실제 낚시를 오래 진행하면서 나오는 모든 모습
private func simulatedFishingFrames() -> [FishingFrame] {
    var session = FishingSession()
    var frames: [FishingFrame] = []
    (0..<(60 * 90)).forEach { _ in
        session.update(deltaTime: 1.0 / 60, random: middle)
        frames.append(session.frame)
    }
    return frames
}

@Test func fishingPiecesStayInsideTheCanvasExceptAFishRisingFromBelow() {
    simulatedFishingFrames().forEach { frame in
        FishingPieces.pieces(frame: frame, bodyColor: IconPalette.whiteBody).forEach { piece in
            let rect = piece.rect
            #expect(rect.x >= 0)
            #expect(rect.y >= 0)
            #expect(rect.x + rect.width <= CharacterGrid.canvasWidth)
            // 끌어올리는 물고기는 아래쪽에서 올라오므로 처음에는 아래가 캔버스 밖에 있다.
            if !frame.hasFish {
                #expect(rect.y + rect.height <= CharacterGrid.canvasHeight)
            }
        }
    }
}

@Test func theSimulatedSessionShowsEveryEyeAndRodPose() {
    let frames = simulatedFishingFrames()

    #expect(Set(frames.map(\.eyes)) == [.closed, .open, .wide])
    #expect(Set(frames.map(\.rod)) == [.rest, .up, .down, .bent])
}

@Test func fishAppearsOnlyWhenCaughtAndHookOnlyBefore() {
    let waiting = FishingSession().frame
    var caught = FishingSession()
    caught.update(deltaTime: FishingSession.firstWait + FishingSession.biteDuration + FishingSession.reelDuration + 0.1, random: middle)

    let waitingPieces = FishingPieces.pieces(frame: waiting, bodyColor: IconPalette.whiteBody)
    let caughtPieces = FishingPieces.pieces(frame: caught.frame, bodyColor: IconPalette.whiteBody)

    #expect(waitingPieces.contains { $0.color == IconPalette.fishingHook })
    #expect(!waitingPieces.contains { $0.color == IconPalette.fishBody })
    #expect(caughtPieces.contains { $0.color == IconPalette.fishBody })
    #expect(!caughtPieces.contains { $0.color == IconPalette.fishingHook })
}

@Test func theBubbleShowsOnlyWhileBiting() {
    var session = FishingSession()
    let before = FishingPieces.pieces(frame: session.frame, bodyColor: IconPalette.whiteBody)
    session.update(deltaTime: FishingSession.firstWait + 0.1, random: middle)
    let during = FishingPieces.pieces(frame: session.frame, bodyColor: IconPalette.whiteBody)

    #expect(!before.contains { $0.color == IconPalette.fishingBubble })
    #expect(during.contains { $0.color == IconPalette.fishingBubble })
}

@Test func fishingSceneKeepsTheUnseenDoneDotLikeSleeping() {
    let frame = FishingSession().frame
    let plain = IconScene.pieces(frame: .fishing(frame), appearance: IconAppearance())
    let withDot = IconScene.pieces(frame: .fishing(frame), appearance: IconAppearance(hasUnseenDone: true))

    #expect(!plain.contains { $0.color == IconPalette.doneDot })
    #expect(withDot.contains { $0.color == IconPalette.doneDot })
}

@Test func scheduleChoosesFishingOnlyWhenNothingElseIsGoingOn() {
    #expect(IconSchedule(isRunning: false, hasFirework: false, rest: .fishing) == .fishing)
    #expect(IconSchedule(isRunning: true, hasFirework: false, rest: .fishing) == .running)
    #expect(IconSchedule(isRunning: false, hasFirework: true, rest: .fishing) == .running)
    #expect(IconSchedule(isRunning: false, hasFirework: false, rest: .sleeping) == .sleeping)
    #expect(IconSchedule(isRunning: false, hasFirework: false, rest: nil) == .still)
    #expect(IconSchedule.fishing.interval == IconTiming.fishingTickInterval)
}
