import CoreGraphics
import DesignSystem

/// 메뉴바에 보여 줄 모습. 달리기와 잠듦의 번호는 한 바퀴 안으로 감긴다.
public enum IconFrame: Equatable, Sendable {
    case standing
    /// 대기 중에 마우스 쪽을 바라보는 모습. 정면(.center)은 .standing과 같은 그림이다.
    case gazing(GazeDirection)
    /// 대기 중에 표정이 바뀐 모습. 표정이 .open이면 .gazing과 같은 그림이다.
    case expression(EyeExpression, GazeDirection)
    /// 대기 중에 그림 캐릭터가 움직이는 모습. clip은 대기 클립 번호, frame은 그 클립의 GIF 프레임 번호다.
    case idle(clip: Int, frame: Int)
    case running(phase: Int)
    case sleeping(frame: Int)
    /// 쉬는 동안 메뉴바에서 낚시하는 모습
    case fishing(FishingFrame)
    /// 쉬는 동안 하는 일 중 정해진 장면이 되풀이되는 것(스파클라, 음악, 음료, 별똥별, 비, 비눗방울)
    case rest(RestFrame)
}

/// 한 가지 색으로 칠하는 사각형. 장면은 이 목록을 순서대로 칠한 결과다.
struct IconPiece: Equatable, Sendable {
    let rect: UnitRect
    let color: IconColor
}

/// 그림 캐릭터를 놓을 자리. originX와 originY는 24x17칸 캐릭터 영역의 왼쪽 위 모서리이고, pose는 어떤 그림을 쓸지다.
struct ImagePlacement: Equatable, Sendable {
    let character: IconCharacter
    let pose: ArtPose
    /// 같은 자세 안에서 고를 프레임 번호(GIF에서 뽑은 그림)
    let frame: Int
    /// 그림의 가로 가운데, 아래 끝, 높이(캔버스 칸 단위)
    let centerX: CGFloat
    let bottom: CGFloat
    let height: CGFloat

    /// 사각형 캐릭터와 같은 기준(24x17칸 영역의 왼쪽 위 originX, originY)으로 놓는다.
    /// 잘 보이도록 캔버스 높이(20칸)를 꽉 채우고, 서 있을 때 아래 끝이 캔버스 바닥에 닿는다. 아래로 내려가는 폭은 사각형 캐릭터의 절반이다.
    static func standard(character: IconCharacter, pose: ArtPose, frame: Int = 0, originX: CGFloat, originY: CGFloat) -> ImagePlacement {
        ImagePlacement(
            character: character,
            pose: pose,
            frame: frame,
            centerX: originX + CharacterGrid.characterWidth / 2,
            bottom: CharacterGrid.canvasHeight + (originY - CharacterGrid.maxBobHeight) / 2,
            height: CharacterGrid.canvasHeight
        )
    }
}

/// 프레임을 그릴 사각형 목록으로 바꾼다. AppKit을 쓰지 않아서 그리지 않고도 결과를 검사할 수 있다.
/// 좌표는 캔버스 왼쪽 위를 (0, 0)으로 둔 칸 단위이며, 목록의 앞쪽이 아래에 깔린다.
enum IconScene {
    static func pieces(frame: IconFrame, appearance: IconAppearance) -> [IconPiece] {
        // 그림 캐릭터는 그림(imagePlacement)과 풍경(backdrop)을 따로 그리고, 사각형으로는 배지만 그린다.
        guard appearance.character == .claude else { return pictureBadgePieces(frame: frame, appearance: appearance) }
        return contentPieces(frame: frame, appearance: appearance)
    }

    /// 그림 캐릭터의 배지. 치이카와는 달릴 때 오른쪽으로 이동해서 배지도 따라가고, 나머지는 서 있는 자리에 둔다.
    private static func pictureBadgePieces(frame: IconFrame, appearance: IconAppearance) -> [IconPiece] {
        switch frame {
        case .running(let phase) where appearance.character == .chiikawa:
            return badgePieces(appearance.badge, characterOriginX: RunningFrame(phase: phase).originX)
        case .sleeping, .fishing, .rest:
            // 쉬는 모습처럼 확인하지 않은 완료 점만 보여 준다. 그림 캐릭터는 쉬는 동작을 하지 않지만 모습을 받으면 이렇게 그린다.
            return appearance.hasUnseenDone ? badgePieces(.unseenDone, characterOriginX: CharacterGrid.standingOriginX) : []
        case .standing, .gazing, .expression, .idle, .running:
            return badgePieces(appearance.badge, characterOriginX: CharacterGrid.standingOriginX)
        }
    }

    private static func contentPieces(frame: IconFrame, appearance: IconAppearance) -> [IconPiece] {
        let bodyColor = IconPalette.bodyColor(for: appearance.colorMode)

        switch frame {
        case .standing, .idle:
            let originX = CharacterGrid.standingOriginX
            return characterPieces(pose: .standing, bodyColor: bodyColor, originX: originX, originY: CharacterGrid.maxBobHeight)
                + badgePieces(appearance.badge, characterOriginX: originX)

        case .gazing(let direction):
            let originX = CharacterGrid.standingOriginX
            return characterPieces(pose: .standing, gaze: direction, bodyColor: bodyColor, originX: originX, originY: CharacterGrid.maxBobHeight)
                + badgePieces(appearance.badge, characterOriginX: originX)

        case .expression(let expression, let direction):
            let originX = CharacterGrid.standingOriginX
            return sparkPieces(for: expression)
                + characterPieces(pose: .standing, gaze: direction, expression: expression, bodyColor: bodyColor, originX: originX, originY: CharacterGrid.maxBobHeight)
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

        case .fishing(let fishingFrame):
            let character = FishingPieces.pieces(frame: fishingFrame, bodyColor: bodyColor)
            // 잠든 모습처럼 확인하지 않은 완료 점만 보여 준다.
            if appearance.hasUnseenDone {
                return character + badgePieces(.unseenDone, characterOriginX: FishingPieces.originX)
            }
            return character

        case .rest(let restFrame):
            let scene = RestScenes.pieces(frame: restFrame, bodyColor: bodyColor)
            // 잠든 모습처럼 확인하지 않은 완료 점만 보여 준다.
            if appearance.hasUnseenDone {
                return scene + badgePieces(.unseenDone, characterOriginX: CharacterGrid.standingOriginX)
            }
            return scene
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

    /// 애니 장면 배경의 자리. 치이카와는 들판을 깔고 달릴 때 들판이 흘러간다. 하치와레(문 앞)와 우사기(숲속)는 제자리에서 춤춰서 배경도 고정이다.
    static func backdrop(frame: IconFrame, appearance: IconAppearance) -> BackdropPlacement? {
        switch (appearance.character, frame) {
        case (.claude, _): return nil
        case (.hachiware, _): return BackdropPlacement(scene: .gate, grassShift: nil)
        case (.usagi, _): return BackdropPlacement(scene: .forest, grassShift: nil)
        case (.chiikawa, .running(let phase)): return BackdropPlacement(grassShift: SceneBackdrop.grassShift(phase: phase))
        case (.chiikawa, _): return BackdropPlacement(grassShift: nil)
        }
    }

    /// 그림으로 그리는 캐릭터(치이카와, 하치와레, 우사기)가 놓일 자리. 사각형 캐릭터(Claude)는 nil이다.
    /// 위치는 사각형 캐릭터와 같은 기준이라서 달리기, 잠듦, 배지 자리가 그대로 맞는다.
    static func imagePlacement(frame: IconFrame, appearance: IconAppearance) -> ImagePlacement? {
        guard appearance.character != .claude else { return nil }
        let character = appearance.character
        let stillFrame = CharacterArt.stillIdleFrame
        switch frame {
        // 그림 캐릭터에는 시선, 표정, 쉬는 모습이 없어서 서 있는 모습으로 그린다.
        case .standing, .gazing, .expression, .fishing, .rest:
            return .standard(character: character, pose: .resting, frame: stillFrame, originX: CharacterGrid.standingOriginX, originY: CharacterGrid.maxBobHeight)
        case .idle(let clip, let frame):
            let clipCount = CharacterArt.idleClips(of: character).count
            guard clipCount > 0 else {
                return .standard(character: character, pose: .resting, frame: stillFrame, originX: CharacterGrid.standingOriginX, originY: CharacterGrid.maxBobHeight)
            }
            return .standard(character: character, pose: .idle(clip: wrapFrameIndex(clip, count: clipCount)), frame: frame, originX: CharacterGrid.standingOriginX, originY: CharacterGrid.maxBobHeight)
        case .running(let phase):
            let running = RunningFrame(phase: phase)
            // 하치와레와 우사기는 달리지 않고 제자리에서 춤춘다.
            let dancesInPlace = character == .hachiware || character == .usagi
            let originX = dancesInPlace ? CharacterGrid.standingOriginX : running.originX
            // 달릴 때는 GIF에서 뽑은 뛰는 프레임을 한 바퀴(24칸)에 한 번 돌린다. 통통 튀는 움직임은 프레임에 들어 있어서 높이는 고정한다.
            let frameCount = max(1, CharacterArt.frameCount(of: character, pose: .running))
            let artFrame = wrapFrameIndex(phase, count: IconTiming.runningFrameCount) * frameCount / IconTiming.runningFrameCount
            // 보여 줄 범위(상반신)가 캔버스 높이를 채우도록 확대한다. 범위 위쪽 끝이 캔버스 위쪽 끝에 오고, 나머지는 캔버스 밖으로 나가 잘린다.
            let visible = CharacterArt.runningVisibleRange(of: character)
            let height = CharacterGrid.canvasHeight / (visible.upperBound - visible.lowerBound)
            let top = -visible.lowerBound * height
            return ImagePlacement(
                character: character,
                pose: .running,
                frame: artFrame,
                centerX: originX + CharacterGrid.characterWidth / 2,
                bottom: top + height,
                height: height
            )
        case .sleeping:
            return .standard(
                character: character,
                pose: .resting,
                frame: stillFrame,
                originX: CharacterGrid.standingOriginX,
                originY: CharacterGrid.maxBobHeight + CharacterGrid.sleepDropHeight
            )
        }
    }

    // 그리는 순서는 다리, 팔, 몸통, 입, 눈이다.
    static func characterPieces(
        pose: LegPose,
        gaze: GazeDirection = .center,
        expression: EyeExpression = .open,
        bodyColor: IconColor,
        originX: CGFloat,
        originY: CGFloat
    ) -> [IconPiece] {
        let rects = CharacterGrid.rects(for: pose, gaze: gaze, expression: expression)
        let bodyRects = rects.legs + rects.arms + [rects.body]
        return bodyRects.map { IconPiece(rect: $0.offsetBy(x: originX, y: originY), color: bodyColor) }
            + (rects.mouth + rects.eyes).map { IconPiece(rect: $0.offsetBy(x: originX, y: originY), color: IconPalette.eye) }
    }

    /// 어지러울 때만 있다. 캐릭터보다 먼저 그려서 뒤에서 반짝이게 한다.
    private static func sparkPieces(for expression: EyeExpression) -> [IconPiece] {
        guard case .dizzy(let phase) = expression else { return [] }
        return DizzySparks.rects(phase: phase).map { IconPiece(rect: $0, color: IconPalette.dizzySpark) }
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
