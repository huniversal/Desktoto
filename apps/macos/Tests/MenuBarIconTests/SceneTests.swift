import CoreGraphics
import DesignSystem
import Testing
@testable import MenuBarIcon

private func pieces(_ frame: IconFrame, colorMode: ColorMode = .white, hasUnseenDone: Bool = false, isWaiting: Bool = false) -> [IconPiece] {
    IconScene.pieces(frame: frame, appearance: IconAppearance(colorMode: colorMode, hasUnseenDone: hasUnseenDone, isWaiting: isWaiting))
}

@Test func waitingBadgeWinsOverUnseenDone() {
    #expect(IconBadge(hasUnseenDone: false, isWaiting: false) == .none)
    #expect(IconBadge(hasUnseenDone: true, isWaiting: false) == .unseenDone)
    #expect(IconBadge(hasUnseenDone: false, isWaiting: true) == .waiting)
    #expect(IconBadge(hasUnseenDone: true, isWaiting: true) == .waiting)
}

@Test func standingCharacterIsCenteredAndDrawnInOriginalOrder() {
    let standing = pieces(.standing)

    // 다리 4, 팔 2, 몸통 1, 눈 2. 배지가 없다.
    #expect(standing.count == 9)
    #expect(standing[0].rect == UnitRect(13, 14, 2, 4))
    #expect(standing[4].rect == UnitRect(9, 8, 3, 3))
    #expect(standing[6].rect == UnitRect(12, 2, 18, 12))
    #expect(standing[7].rect == UnitRect(15, 5, 2, 3))
    #expect(standing[7].color == IconPalette.eye)
}

@Test func colorModeChangesOnlyTheBodyColor() {
    let white = pieces(.standing, colorMode: .white)
    let colorful = pieces(.standing, colorMode: .color)

    #expect(white.map(\.rect) == colorful.map(\.rect))
    #expect(white[6].color == .gray(white: 1, alpha: 1))
    let orange = IconColor.srgb(red: CGFloat(0xDD) / 255, green: CGFloat(0x8B) / 255, blue: CGFloat(0x70) / 255, alpha: 1)
    #expect(colorful[6].color == orange)
    #expect(white[7].color == colorful[7].color)
}

@Test func standingBadgesSitAtTheRightOfTheCharacter() {
    let waiting = pieces(.standing, isWaiting: true).filter { $0.color == IconPalette.question }
    let done = pieces(.standing, hasUnseenDone: true).filter { $0.color == IconPalette.doneDot }

    // 물음표는 5x7 격자에서 10칸을 칠하고 완료 점은 4x4 한 덩어리다. 위치는 9 + 24 + 1 = 34칸부터다.
    #expect(waiting.count == 10)
    #expect(waiting.allSatisfy { $0.rect.x >= 34 && $0.rect.x < 39 && $0.rect.y >= 0 && $0.rect.y < 7 })
    #expect(done.map(\.rect) == [UnitRect(34, 0, 4, 4)])
    #expect(done.count == 1)
}

@Test func waitingBadgeReplacesTheDoneDotWhenBothExist() {
    let both = pieces(.standing, hasUnseenDone: true, isWaiting: true)

    #expect(both.contains { $0.color == IconPalette.question })
    #expect(!both.contains { $0.color == IconPalette.doneDot })
}

@Test func runningBadgeFollowsTheCharacterHorizontallyButNotTheBob() {
    let phase = 12
    let originX = RunningFrame(phase: phase).originX
    let done = pieces(.running(phase: phase), hasUnseenDone: true).filter { $0.color == IconPalette.doneDot }

    #expect(done.map(\.rect) == [UnitRect(originX + 25, 0, 4, 4)])
}

@Test func runningDrawsSpeedLinesBeforeTheCharacter() {
    let running = pieces(.running(phase: 12))

    #expect(running.prefix(3).allSatisfy { $0.color == IconPalette.speedLine })
    #expect(running.count == 3 + 9)
    #expect(pieces(.running(phase: 0)).count == 9)
}

@Test func sleepingCharacterSinksOneUnitWithClosedEyes() {
    let sleeping = pieces(.sleeping(frame: 5))

    // z가 없는 프레임: 몸통은 서 있을 때보다 1칸 아래이고 눈은 한 줄이다.
    #expect(sleeping.count == 9)
    #expect(sleeping[6].rect == UnitRect(12, 3, 18, 12))
    #expect(sleeping[7].rect == UnitRect(15, 8, 2, 1))
}

@Test func sleepingShowsZAtTheBadgeSlot() {
    let zPieces = pieces(.sleeping(frame: 0)).filter { $0.color == IconPalette.sleepZ }

    // 작은 z(4x4)는 10칸이며 배지 자리 왼쪽(34칸), 위에서 11칸에서 시작한다.
    #expect(zPieces.count == 10)
    #expect(zPieces.first?.rect == UnitRect(34, 11, 1, 1))

    let bigPlusSmall = pieces(.sleeping(frame: 2)).filter { $0.color == IconPalette.sleepZ }
    #expect(bigPlusSmall.count == 10 + 13)
}

@Test func sleepingShowsTheDoneDotInsteadOfZ() {
    let sleeping = pieces(.sleeping(frame: 2), hasUnseenDone: true)

    #expect(!sleeping.contains { $0.color == IconPalette.sleepZ })
    #expect(sleeping.filter { $0.color == IconPalette.doneDot }.map(\.rect) == [UnitRect(34, 0, 4, 4)])
}

@Test func sleepingIgnoresTheWaitingBadgeLikeTheOriginal() {
    let sleeping = pieces(.sleeping(frame: 0), isWaiting: true)

    #expect(!sleeping.contains { $0.color == IconPalette.question })
    #expect(sleeping.contains { $0.color == IconPalette.sleepZ })
}

@Test func everyCharacterFrameStaysInsideTheCanvas() {
    let frames: [IconFrame] = [.standing]
        + (0..<IconTiming.runningFrameCount).map { .running(phase: $0) }
        + (0..<IconTiming.sleepFrameCount).map { .sleeping(frame: $0) }
    let appearances = [
        IconAppearance(),
        IconAppearance(hasUnseenDone: true),
        IconAppearance(isWaiting: true)
    ]

    for frame in frames {
        for appearance in appearances {
            for piece in IconScene.pieces(frame: frame, appearance: appearance) {
                #expect(piece.rect.x >= 0 && piece.rect.x + piece.rect.width <= CharacterGrid.canvasWidth)
                #expect(piece.rect.y >= 0 && piece.rect.y + piece.rect.height <= CharacterGrid.canvasHeight)
            }
        }
    }
}

@Test func fireworkPiecesFadeWithTheFrame() {
    let first = IconScene.fireworkPieces(frame: 0)
    let last = IconScene.fireworkPieces(frame: 23)

    #expect(first.count == 15)
    #expect(first.last?.color == .gray(white: 1, alpha: 1))
    #expect(last.count == 14)
    #expect(last.allSatisfy { piece in
        if case .calibrated(_, _, _, let alpha) = piece.color { return alpha == 0 }
        return false
    })
}
