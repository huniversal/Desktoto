import CoreGraphics
import Testing
@testable import MenuBarIcon

@Test func canvasMatchesOriginalSize() {
    #expect(CharacterGrid.characterWidth == 24)
    #expect(CharacterGrid.characterHeight == 17)
    #expect(CharacterGrid.canvasWidth == 42)
    #expect(CharacterGrid.canvasHeight == 20)
    #expect(CharacterGrid.travelWidth == 12)
    #expect(CharacterGrid.standingOriginX == 9)
}

@Test func standingCharacterMatchesOriginalGrid() {
    let rects = CharacterGrid.rects(for: .standing)

    #expect(rects.body == UnitRect(3, 0, 18, 12))
    #expect(rects.eyes == [UnitRect(6, 3, 2, 3), UnitRect(16, 3, 2, 3)])
    #expect(rects.arms == [UnitRect(0, 6, 3, 3), UnitRect(21, 6, 3, 3)])
    #expect(rects.legs == [UnitRect(4, 12, 2, 4), UnitRect(7, 12, 2, 4), UnitRect(15, 12, 2, 4), UnitRect(18, 12, 2, 4)])
}

@Test func legLengthsAndArmOffsetsFollowPose() {
    #expect(CharacterGrid.legLengths(for: .standing) == [4, 4, 4, 4])
    #expect(CharacterGrid.legLengths(for: .runningA) == [5, 3, 5, 3])
    #expect(CharacterGrid.legLengths(for: .runningB) == [3, 5, 3, 5])
    #expect(CharacterGrid.legLengths(for: .sleeping) == [3, 3, 3, 3])

    #expect(CharacterGrid.armOffsets(for: .runningA) == (-1, 1))
    #expect(CharacterGrid.armOffsets(for: .runningB) == (1, -1))
    #expect(CharacterGrid.armOffsets(for: .standing) == (0, 0))
    #expect(CharacterGrid.armOffsets(for: .sleeping) == (0, 0))
}

@Test func sleepingCharacterClosesEyesToOneRow() {
    let rects = CharacterGrid.rects(for: .sleeping)

    #expect(rects.eyes == [UnitRect(6, 5, 2, 1), UnitRect(16, 5, 2, 1)])
}

@Test func everyPoseStaysInsideCharacterArea() {
    let poses: [LegPose] = [.standing, .runningA, .runningB, .sleeping]

    for pose in poses {
        let rects = CharacterGrid.rects(for: pose)
        let all = rects.legs + rects.arms + rects.eyes + [rects.body]
        #expect(all.allSatisfy { $0.x >= 0 && $0.x + $0.width <= CharacterGrid.characterWidth })
        #expect(all.allSatisfy { $0.y >= 0 && $0.y + $0.height <= CharacterGrid.characterHeight })
    }
}

@Test func glyphCellsSkipEmptyCells() {
    let cells = Glyph.cells(of: ["101", "010"], column: 10, row: 2)

    #expect(cells == [UnitRect(10, 2, 1, 1), UnitRect(12, 2, 1, 1), UnitRect(11, 3, 1, 1)])
}

@Test func frameIndexWrapsIncludingNegativeNumbers() {
    #expect(wrapFrameIndex(0, count: 24) == 0)
    #expect(wrapFrameIndex(24, count: 24) == 0)
    #expect(wrapFrameIndex(25, count: 24) == 1)
    #expect(wrapFrameIndex(-1, count: 24) == 23)
}

@Test func totoUsesNarrowVisibleRangeCenteredOnCircle() {
    let range = CharacterGrid.visibleRange(for: .toto)
    #expect(range.width == 20)
    // 원(지름 18칸)의 가운데가 잘라 낸 범위의 가운데와 같다.
    #expect(range.minX + range.width / 2 == CharacterGrid.standingOriginX + CharacterGrid.characterWidth / 2)
    #expect(CharacterGrid.visibleRange(for: .claude).width == CharacterGrid.canvasWidth)
}

@Test func totoDrawsNoBadgeAndShowsUnseenDoneWithBodyColor() {
    // 토토는 완료 점이나 물음표를 그리지 않는다. 확인하지 않은 완료는 몸 색(TotoArt)으로 보여 준다.
    let appearance = IconAppearance(hasUnseenDone: true, isWaiting: true, character: .toto)
    #expect(IconScene.pieces(frame: .standing, appearance: appearance).isEmpty)
    #expect(IconScene.pieces(frame: .sleeping(frame: 0), appearance: appearance).isEmpty)
}
