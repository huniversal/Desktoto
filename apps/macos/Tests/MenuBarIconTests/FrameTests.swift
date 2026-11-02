import CoreGraphics
import Foundation
import Testing
@testable import MenuBarIcon

@Test func timingMatchesOriginal() {
    #expect(IconTiming.runningFrameCount == 24)
    #expect(IconTiming.runningFrameInterval == 1.0 / 24.0)
    #expect(IconTiming.sleepFrameCount == 6)
    #expect(IconTiming.sleepFrameInterval == 0.6)
    #expect(IconTiming.fireworkFrameCount == 24)
    #expect(IconTiming.runningFrameCount % RunningFrame.framesPerLegStep == 0)
}

@Test func runningPositionDividesTravelWithoutReachingTheEnd() {
    let positions = (0..<IconTiming.runningFrameCount).map { RunningFrame(phase: $0).originX }

    #expect(positions.first == 0)
    #expect(RunningFrame(phase: 12).originX == 6)
    #expect(abs(RunningFrame(phase: 23).originX - 11.5) < 1e-12)
    #expect(positions == positions.sorted())
    #expect(Set(positions).count == positions.count)
    #expect(positions.allSatisfy { $0 < CharacterGrid.travelWidth })
}

@Test func runningLegsSwapEveryThreeFramesAndLoopEvenly() {
    let poses = (0..<IconTiming.runningFrameCount).map { RunningFrame(phase: $0).pose }

    #expect(poses[0...2].allSatisfy { $0 == .runningA })
    #expect(poses[3...5].allSatisfy { $0 == .runningB })
    #expect(poses[6...8].allSatisfy { $0 == .runningA })

    // 한 바퀴를 돌아 첫 프레임으로 돌아올 때까지 교대 횟수는 짝수여야 어긋나지 않는다.
    let swapCount = poses.indices.filter { poses[$0] != poses[($0 + 1) % poses.count] }.count
    #expect(swapCount == 8)
    #expect(swapCount % 2 == 0)
}

@Test func runningBodyBobsBetweenLowAndHighPoses() {
    #expect(RunningFrame(phase: 0).originY == 2)
    #expect(abs(RunningFrame(phase: 3).originY) < 1e-12)
    #expect(abs(RunningFrame(phase: 6).originY - 2) < 1e-12)
    #expect(abs(RunningFrame(phase: 1).originY - 2 * (0.5 + 0.5 * cos(Double.pi / 3))) < 1e-12)

    let heights = (0..<IconTiming.runningFrameCount).map { RunningFrame(phase: $0).originY }
    #expect(heights.allSatisfy { $0 >= -1e-12 && $0 <= CharacterGrid.maxBobHeight + 1e-12 })
}

@Test func runningPhaseWrapsLikeALoop() {
    #expect(RunningFrame(phase: 24) == RunningFrame(phase: 0))
    #expect(RunningFrame(phase: -1) == RunningFrame(phase: 23))
}

@Test func speedLinesTrailBehindAndAreCutAtTheLeftEdge() {
    #expect(SpeedLines.rects(originX: 0, originY: 2).isEmpty)

    // 캐릭터가 10칸 지점이면 간격 3, 4, 3 뒤에서 길이 7, 4, 7만큼 그려진다. 첫 줄은 캔버스 왼쪽에서 잘린다.
    let rects = SpeedLines.rects(originX: 10, originY: 2)
    #expect(rects == [UnitRect(0, 4, 7, 2), UnitRect(2, 8, 4, 2), UnitRect(0, 12, 7, 2)])
}

@Test func sleepFramesMatchOriginalTable() {
    #expect(SleepFrames.marksByFrame.count == IconTiming.sleepFrameCount)
    #expect(SleepFrames.marks(frame: 0) == [SleepMark(isBig: false, column: 0, row: 11)])
    #expect(SleepFrames.marks(frame: 1) == [SleepMark(isBig: false, column: 0, row: 9)])
    #expect(SleepFrames.marks(frame: 2) == SleepFrames.marks(frame: 3))
    #expect(SleepFrames.marks(frame: 2).count == 2)
    #expect(SleepFrames.marks(frame: 4) == [SleepMark(isBig: true, column: 2, row: 2)])
    #expect(SleepFrames.marks(frame: 5).isEmpty)
    #expect(SleepFrames.marks(frame: 6) == SleepFrames.marks(frame: 0))
}

@Test func fireworkStartsWithFlashAndFullSparks() {
    let frame = FireworkFrame(frame: 0)

    #expect(frame.sparks.count == 14)
    #expect(frame.sparks.allSatisfy { $0.alpha == 1 })
    #expect(frame.sparks.allSatisfy { $0.rect.width == 3 })
    #expect(frame.flash == FireworkFlash(rect: UnitRect(19, 7, 4, 4), alpha: 1))

    // 첫 알갱이: 각도 0.3, 반지름 8(아직 퍼지지 않음), 중심 (21, 9)
    let first = frame.sparks[0].rect
    #expect(abs(first.x - (21 + cos(0.3) * 8 - 1.5)) < 1e-9)
    #expect(abs(first.y - (9 + sin(0.3) * 8 * 0.5 - 1.5)) < 1e-9)
}

@Test func fireworkFadesOutCompletelyAtTheLastFrame() {
    let frame = FireworkFrame(frame: IconTiming.fireworkFrameCount - 1)

    #expect(frame.sparks.allSatisfy { $0.alpha == 0 })
    #expect(frame.sparks.allSatisfy { $0.rect.width == 1 })
    #expect(frame.flash == nil)
}

@Test func fireworkSparkSizeShrinksAtThresholds() {
    func size(at frame: Int) -> CGFloat { FireworkFrame(frame: frame).sparks[0].rect.width }

    #expect(size(at: 10) == 3)
    #expect(size(at: 11) == 2)
    #expect(size(at: 18) == 2)
    #expect(size(at: 19) == 1)
}

@Test func fireworkFlashLastsOnlyTheFirstFifthOfTheFrames() {
    #expect(FireworkFrame(frame: 4).flash != nil)
    #expect(FireworkFrame(frame: 5).flash == nil)
}

@Test func fireworkSparksSpreadOutwardAndCycleColors() {
    let early = FireworkFrame(frame: 0).sparks
    let late = FireworkFrame(frame: 20).sparks

    func distance(_ spark: FireworkSpark) -> CGFloat {
        let centerX = spark.rect.x + spark.rect.width / 2 - 21
        return abs(centerX)
    }
    #expect(distance(late[0]) > distance(early[0]))
    #expect(early.map(\.colorIndex) == (0..<14).map { $0 % 5 })
}
