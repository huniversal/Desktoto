import CoreGraphics
import Testing
@testable import MenuBarIcon

@Test func mouseInsideDeadZoneLooksStraightAhead() {
    #expect(GazeDirection.make(offsetX: 0, offsetY: 0) == .center)
    #expect(GazeDirection.make(offsetX: 14, offsetY: -9) == .center)
}

@Test func gazeLevelGrowsWithMouseDistance() {
    let near = GazeDirection.make(offsetX: 80, offsetY: 0)
    let middle = GazeDirection.make(offsetX: 150, offsetY: 0)
    let far = GazeDirection.make(offsetX: 250, offsetY: 0)

    #expect(near.horizontal > 0)
    #expect(middle.horizontal > near.horizontal)
    #expect(far.horizontal == GazeDirection.maxHorizontal)
    #expect(GazeDirection.make(offsetX: 5000, offsetY: 0).horizontal == GazeDirection.maxHorizontal)
}

@Test func mouseDirectionMapsToGazeInScreenCoordinates() {
    #expect(GazeDirection.make(offsetX: -250, offsetY: 0) == GazeDirection(horizontal: -GazeDirection.maxHorizontal, vertical: 0))
    #expect(GazeDirection.make(offsetX: 250, offsetY: 0) == GazeDirection(horizontal: GazeDirection.maxHorizontal, vertical: 0))
    // 화면 좌표는 위쪽이 +y라서 마우스가 아래에 있으면 offsetY가 음수이고 시선은 아래(양수)다.
    #expect(GazeDirection.make(offsetX: 0, offsetY: -150) == GazeDirection(horizontal: 0, vertical: GazeDirection.maxVertical))
    #expect(GazeDirection.make(offsetX: 0, offsetY: 150) == GazeDirection(horizontal: 0, vertical: -GazeDirection.maxVertical))
}

@Test func gazeIndexCoversEverySlotOnce() {
    let directions = (0..<GazeDirection.count).map { GazeDirection(index: $0) }

    #expect(Set(directions).count == GazeDirection.count)
    #expect(directions.map(\.index) == Array(0..<GazeDirection.count))
    #expect(GazeDirection(horizontal: 99, vertical: -99) == GazeDirection(horizontal: GazeDirection.maxHorizontal, vertical: -GazeDirection.maxVertical))
}

@Test func positionEasesTowardTheTargetAndSlowsDown() {
    let target = GazeDirection(horizontal: 6, vertical: 0)
    var position = GazePosition.center
    var steps: [Double] = []

    while !position.hasReached(target) {
        let next = position.eased(toward: target)
        steps.append(next.horizontal - position.horizontal)
        position = next
    }

    #expect(position.direction == target)
    #expect(steps.count < 20)
    // 처음에는 크게, 목표에 가까울수록 작게 움직인다(마지막 한 번은 남은 거리를 붙이는 단계다).
    #expect(steps[0] > steps[1] && steps[1] > steps[2])
    #expect(steps.allSatisfy { $0 > 0 })
}

@Test func positionSnapsOnceTheRemainingDistanceIsHalfALevelOrLess() {
    let target = GazeDirection(horizontal: 3, vertical: 2)
    let near = GazePosition(horizontal: 2.5, vertical: 1.6)

    #expect(near.eased(toward: target).hasReached(target))
    #expect(GazePosition.center.eased(toward: .center).hasReached(.center))
}

@Test func positionDirectionRoundsToTheNearestLevel() {
    #expect(GazePosition(horizontal: 1.4, vertical: -0.6).direction == GazeDirection(horizontal: 1, vertical: -1))
    #expect(GazePosition(horizontal: -2.6, vertical: 0.4).direction == GazeDirection(horizontal: -3, vertical: 0))
}

@Test func positionNeverMovesMoreThanTheDistanceToTheTarget() {
    (0..<GazeDirection.count).forEach { index in
        let target = GazeDirection(index: index)
        let next = GazePosition.center.eased(toward: target)
        #expect(abs(next.horizontal) <= abs(Double(target.horizontal)))
        #expect(abs(next.vertical) <= abs(Double(target.vertical)))
    }
}

@Test func centerGazeMatchesStandingGrid() {
    #expect(CharacterGrid.rects(for: .standing, gaze: .center) == CharacterGrid.rects(for: .standing))
}

@Test func eyesMoveHalfACellPerLevelAndHeadMovesLess() {
    let one = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 1, vertical: 0))
    #expect(one.eyes == [UnitRect(6.5, 3, 2, 3), UnitRect(16.5, 3, 2, 3)])

    let half = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 3, vertical: 0))
    #expect(half.eyes == [UnitRect(7.5, 3, 2, 3), UnitRect(17.5, 3, 2, 3)])
    #expect(half.body == UnitRect(3.5, 0, 18, 12))

    let max = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 6, vertical: 0))
    #expect(max.eyes == [UnitRect(9, 3, 2, 3), UnitRect(19, 3, 2, 3)])
    #expect(max.body == UnitRect(4, 0, 18, 12))

    let down = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 0, vertical: 4))
    #expect(down.eyes == [UnitRect(6, 5, 2, 3), UnitRect(16, 5, 2, 3)])
}

@Test func eyeStepsAreEvenForEveryHorizontalLevel() {
    let xs = (-GazeDirection.maxHorizontal...GazeDirection.maxHorizontal).map {
        CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: $0, vertical: 0)).eyes[0].x
    }
    zip(xs, xs.dropFirst()).forEach { #expect(abs(($1 - $0) - 0.5) < 1e-9) }
}

@Test func armsLeanTogetherWithTheBody() {
    let max = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: 6, vertical: 0))
    #expect(max.arms == [UnitRect(1, 6, 3, 3), UnitRect(22, 6, 3, 3)])

    let left = CharacterGrid.rects(for: .standing, gaze: GazeDirection(horizontal: -6, vertical: 0))
    #expect(left.arms == [UnitRect(-1, 6, 3, 3), UnitRect(20, 6, 3, 3)])

    // 팔과 몸통 사이의 간격은 기울어도 그대로다.
    (0..<GazeDirection.count).forEach { index in
        let rects = CharacterGrid.rects(for: .standing, gaze: GazeDirection(index: index))
        #expect(abs((rects.arms[0].x - rects.body.x) - -3) < 1e-9)
        #expect(abs((rects.arms[1].x - rects.body.x) - 18) < 1e-9)
    }
}

@Test func runningAndSleepingIgnoreGaze() {
    let gaze = GazeDirection(horizontal: 6, vertical: 4)
    #expect(CharacterGrid.rects(for: .runningA, gaze: gaze) == CharacterGrid.rects(for: .runningA))
    #expect(CharacterGrid.rects(for: .sleeping, gaze: gaze) == CharacterGrid.rects(for: .sleeping))
}

@Test func gazeEyesStayInsideBodyForEveryDirection() {
    (0..<GazeDirection.count).forEach { index in
        let rects = CharacterGrid.rects(for: .standing, gaze: GazeDirection(index: index))
        rects.eyes.forEach { eye in
            #expect(eye.x >= rects.body.x && eye.x + eye.width <= rects.body.x + rects.body.width)
            #expect(eye.y >= rects.body.y && eye.y + eye.height <= rects.body.y + rects.body.height)
        }
    }
}
