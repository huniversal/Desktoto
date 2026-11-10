import AppKit
import MenuBarIcon
import MiniGame
import QuartzCore

/// 셔틀콕 랠리 장면. 메뉴바에서 비워진 구간을 캐릭터가 좌우로 달리며 셔틀콕을 친다.
/// 점수는 캐릭터 옆 숫자로만 보여 주고, 끝났을 때는 안내를 캐릭터 아래에 작게 보여 준다.
@MainActor
final class RallyScene: GameScene {
    private static let bestScoreKey = "desktoto.rally.bestScore"
    /// 캐릭터가 달릴 수 있는 범위의 안쪽 여백. 오른쪽에는 캐릭터 옆에 붙는 점수 숫자가 들어갈 자리를 둔다.
    private static let leftMargin: CGFloat = 28
    private static let rightMargin: CGFloat = 64
    /// 캐릭터 가운데에서 점수 숫자가 시작하는 곳까지의 거리
    private static let scoreOffset: CGFloat = 17

    private var game: RallyGame?
    private var context: GameSceneContext?
    private var shownRevision = -1
    private var shownSpriteFrame: IconFrame?

    private let scoreLayer = CATextLayer()
    private let messageLayer = CATextLayer()
    private let racketLayer = CAShapeLayer()
    private let spriteLayer = CALayer()
    private let shuttleLayer = CALayer()

    var isOver: Bool {
        game?.phase == .over
    }

    func begin(context: GameSceneContext) {
        self.context = context
        setUpLayers(context)

        // 캐릭터는 비워진 구간 안에서만 달린다.
        let low = max(context.clearedMinX, context.usableMinX) + Self.leftMargin
        let high = max(low, context.clearedMaxX - Self.rightMargin)
        game = RallyGame(
            court: RallyCourt(
                bounds: CGRect(
                    x: context.usableMinX,
                    y: 0,
                    width: context.screenSize.width - context.usableMinX,
                    height: context.screenSize.height
                ),
                serveOrigin: CGPoint(x: (low + high) / 2, y: context.menuBarBottomY),
                characterRange: low...high
            ),
            bestScore: UserDefaults.standard.integer(forKey: Self.bestScoreKey)
        )
        shownRevision = -1
        shownSpriteFrame = nil
    }

    func update(deltaTime: TimeInterval, now: TimeInterval, mouse: CGPoint) {
        guard var current = game else { return }
        let wasOver = current.phase == .over
        current.update(deltaTime: deltaTime, racket: mouse, random: { Double.random(in: 0...1) })
        game = current
        // 끝나는 순간에 바로 저장한다. 게임 오버 화면에서 앱을 종료하거나 비정상 종료돼도 기록이 남는다.
        if !wasOver, current.phase == .over { saveBestScore(current.bestScore) }
        render(current, racket: mouse, now: now)
    }

    func restart() {
        game?.restart()
    }

    func end() {
        if let best = game?.bestScore { saveBestScore(best) }
        game = nil
        [scoreLayer, messageLayer, racketLayer, spriteLayer, shuttleLayer].forEach {
            $0.removeAllAnimations()
            $0.removeFromSuperlayer()
        }
    }

    private func saveBestScore(_ bestScore: Int) {
        UserDefaults.standard.set(bestScore, forKey: Self.bestScoreKey)
    }

    // MARK: - 레이어

    private func setUpLayers(_ context: GameSceneContext) {
        let scale = context.scale

        // 점수는 메뉴바에서 캐릭터 옆에 숫자로만 보여 준다.
        GameText.configure(scoreLayer, scale: scale, fontSize: 16, weight: .heavy, isMonospaced: true, alignment: .left, size: CGSize(width: 60, height: 22))
        scoreLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        // 끝났을 때 안내는 캐릭터 아래에 작게 보여 준다.
        GameText.configure(messageLayer, scale: scale, fontSize: 11, weight: .semibold, isMonospaced: false, alignment: .center, size: CGSize(width: 220, height: 16))
        messageLayer.foregroundColor = NSColor.black.cgColor
        messageLayer.shadowColor = NSColor.white.cgColor
        messageLayer.anchorPoint = CGPoint(x: 0.5, y: 1)

        let diameter = (RallyGame.racketRadius + RallyGame.shuttleRadius) * 2
        racketLayer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        racketLayer.path = CGPath(ellipseIn: racketLayer.bounds.insetBy(dx: 2, dy: 2), transform: nil)
        racketLayer.fillColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor
        racketLayer.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.95).cgColor
        racketLayer.lineWidth = 2
        racketLayer.shadowColor = NSColor.black.cgColor
        racketLayer.shadowOpacity = 0.45
        racketLayer.shadowRadius = 2
        racketLayer.shadowOffset = .zero

        spriteLayer.bounds = CGRect(origin: .zero, size: context.sprites.image(for: .standing).size)
        spriteLayer.contentsScale = scale
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.shadowColor = NSColor.black.cgColor
        spriteLayer.shadowOpacity = 0.55
        spriteLayer.shadowRadius = 2
        spriteLayer.shadowOffset = .zero

        shuttleLayer.bounds = CGRect(origin: .zero, size: RallyArt.shuttleSize)
        shuttleLayer.contents = RallyArt.shuttleImage(scale: scale)
        shuttleLayer.contentsScale = scale
        shuttleLayer.magnificationFilter = .nearest
        // 형광 빛 번짐으로 배경과 상관없이 눈에 띄게 한다.
        shuttleLayer.shadowColor = RallyArt.neonFeather.cgColor
        shuttleLayer.shadowOpacity = 1
        shuttleLayer.shadowRadius = 7
        shuttleLayer.shadowOffset = .zero

        messageLayer.isHidden = true
        shuttleLayer.isHidden = true
        [scoreLayer, messageLayer, racketLayer, spriteLayer, shuttleLayer].forEach { context.root.addSublayer($0) }
    }

    // MARK: - 그리기

    private func render(_ current: RallyGame, racket: CGPoint, now: TimeInterval) {
        guard let context else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        racketLayer.position = racket
        spriteLayer.position = CGPoint(x: current.characterX, y: context.menuBarCenterY)
        scoreLayer.position = CGPoint(x: current.characterX + Self.scoreOffset, y: context.menuBarCenterY)
        shuttleLayer.position = current.shuttle
        if case .rallying = current.phase {
            shuttleLayer.isHidden = false
        } else {
            shuttleLayer.isHidden = true
        }

        showSprite(spriteFrame(for: current, now: now, context: context), context: context)

        // 게임이 끝나면 안내를 캐릭터 아래에 보여 준다(화면 밖으로 나가지 않게 가로 위치를 제한한다).
        let isOver = current.phase == .over
        messageLayer.isHidden = !isOver
        if isOver {
            let halfWidth = messageLayer.bounds.width / 2
            messageLayer.position = CGPoint(
                x: max(halfWidth, min(context.screenSize.width - halfWidth, current.characterX)),
                y: context.menuBarBottomY - 4
            )
        }

        guard current.revision != shownRevision else { return }
        shownRevision = current.revision
        scoreLayer.string = "\(current.score)"
        messageLayer.string = "SPACE 다시  ESC 끝"
    }

    /// 달릴 때는 달리기 프레임, 서 있을 때는 셔틀콕을 바라보는 모습이다.
    private func spriteFrame(for current: RallyGame, now: TimeInterval, context: GameSceneContext) -> IconFrame {
        if current.isCharacterRunning {
            return .running(phase: Int(now * 24) % IconTiming.runningFrameCount)
        }
        guard case .rallying = current.phase else { return .standing }
        let direction = GazeDirection.make(
            offsetX: current.shuttle.x - current.characterX,
            offsetY: current.shuttle.y - context.menuBarCenterY
        )
        return .gazing(direction)
    }

    private func showSprite(_ frame: IconFrame, context: GameSceneContext) {
        guard frame != shownSpriteFrame else { return }
        shownSpriteFrame = frame
        spriteLayer.contents = context.sprites.image(for: frame).cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
