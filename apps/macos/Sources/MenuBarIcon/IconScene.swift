import CoreGraphics

/// 메뉴바에 보여 줄 모습. 달리기와 잠듦의 번호는 한 바퀴 안으로 감긴다.
public enum IconFrame: Equatable, Sendable {
    case standing
    case running(phase: Int)
    case sleeping(frame: Int)
}

/// 한 가지 색으로 칠하는 사각형. 장면은 이 목록을 순서대로 칠한 결과다.
struct IconPiece: Equatable, Sendable {
    let rect: UnitRect
    let color: IconColor
}

/// 프레임을 그릴 사각형 목록으로 바꾼다. AppKit을 쓰지 않아서 그리지 않고도 결과를 검사할 수 있다.
/// 좌표는 캔버스 왼쪽 위를 (0, 0)으로 둔 칸 단위이며, 목록의 앞쪽이 아래에 깔린다.
enum IconScene {
    static func pieces(frame: IconFrame, appearance: IconAppearance) -> [IconPiece] {
        let bodyColor = IconPalette.bodyColor(for: appearance.colorMode)

        switch frame {
        case .standing:
            let originX = CharacterGrid.standingOriginX
            return characterPieces(pose: .standing, bodyColor: bodyColor, originX: originX, originY: CharacterGrid.maxBobHeight)
                + badgePieces(appearance.badge, characterOriginX: originX)

        case .running(let phase):
            let running = RunningFrame(phase: phase)
            return speedLinePieces(originX: running.originX, originY: running.originY)
                + characterPieces(pose: running.pose, bodyColor: bodyColor, originX: running.originX, originY: running.originY)
                + badgePieces(appearance.badge, characterOriginX: running.originX)

        case .sleeping(let sleepFrame):
            let originX = CharacterGrid.standingOriginX
            let originY = CharacterGrid.maxBobHeight + CharacterGrid.sleepDropHeight
            let character = characterPieces(pose: .sleeping, bodyColor: bodyColor, originX: originX, originY: originY)
            // 확인하지 않은 완료 점이 있으면 z 대신 점을 그린다(같은 자리를 쓴다). 잠든 모습은 승인 대기 표시를 그리지 않는다.
            if appearance.hasUnseenDone {
                return character + badgePieces(.unseenDone, characterOriginX: originX)
            }
            return character + sleepMarkPieces(frame: sleepFrame, badgeX: BadgeGrid.originX(characterOriginX: originX))
        }
    }

    /// 폭죽 프레임. 캐릭터보다 먼저 그려서 뒤에서 터지는 것처럼 보이게 한다.
    static func fireworkPieces(frame: Int) -> [IconPiece] {
        let firework = FireworkFrame(frame: frame)
        let sparks = firework.sparks.map {
            IconPiece(rect: $0.rect, color: IconPalette.fireworkSparks[$0.colorIndex].with(alpha: $0.alpha))
        }
        guard let flash = firework.flash else { return sparks }
        return sparks + [IconPiece(rect: flash.rect, color: IconPalette.fireworkFlash.with(alpha: flash.alpha))]
    }

    // 그리는 순서는 다리, 팔, 몸통, 눈이다.
    private static func characterPieces(pose: LegPose, bodyColor: IconColor, originX: CGFloat, originY: CGFloat) -> [IconPiece] {
        let rects = CharacterGrid.rects(for: pose)
        let bodyRects = rects.legs + rects.arms + [rects.body]
        return bodyRects.map { IconPiece(rect: $0.offsetBy(x: originX, y: originY), color: bodyColor) }
            + rects.eyes.map { IconPiece(rect: $0.offsetBy(x: originX, y: originY), color: IconPalette.eye) }
    }

    private static func speedLinePieces(originX: CGFloat, originY: CGFloat) -> [IconPiece] {
        SpeedLines.rects(originX: originX, originY: originY).map { IconPiece(rect: $0, color: IconPalette.speedLine) }
    }

    private static func badgePieces(_ badge: IconBadge, characterOriginX: CGFloat) -> [IconPiece] {
        let badgeX = BadgeGrid.originX(characterOriginX: characterOriginX)
        switch badge {
        case .none:
            return []
        case .waiting:
            return Glyph.cells(of: BadgeGrid.questionGlyph, column: badgeX, row: 0)
                .map { IconPiece(rect: $0, color: IconPalette.question) }
        case .unseenDone:
            return [IconPiece(rect: UnitRect(badgeX, 0, BadgeGrid.doneDotSize, BadgeGrid.doneDotSize), color: IconPalette.doneDot)]
        }
    }

    private static func sleepMarkPieces(frame: Int, badgeX: CGFloat) -> [IconPiece] {
        SleepFrames.marks(frame: frame).flatMap { mark in
            Glyph.cells(
                of: mark.isBig ? SleepFrames.bigGlyph : SleepFrames.smallGlyph,
                column: badgeX + mark.column,
                row: mark.row
            )
        }
        .map { IconPiece(rect: $0, color: IconPalette.sleepZ) }
    }
}
