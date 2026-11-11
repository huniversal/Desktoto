import CoreGraphics
import Foundation

/// 게임이 벌어지는 화면. 좌표는 화면 왼쪽 아래를 (0, 0)으로 두고 위쪽이 +y다(AppKit 화면 좌표와 같다).
public struct RallyCourt: Equatable, Sendable {
    /// 셔틀콕이 날아다니는 범위. 보통 화면 전체다.
    public var bounds: CGRect
    /// 캐릭터가 셔틀콕을 치는 자리. 메뉴바 캐릭터의 아래쪽 가운데다. x는 캐릭터의 처음 위치다.
    public var serveOrigin: CGPoint
    /// 캐릭터가 좌우로 달릴 수 있는 가로 범위. 정하지 않으면 제자리에서만 친다.
    public var characterRange: ClosedRange<CGFloat>

    public init(bounds: CGRect, serveOrigin: CGPoint, characterRange: ClosedRange<CGFloat>? = nil) {
        self.bounds = bounds
        self.serveOrigin = serveOrigin
        self.characterRange = characterRange ?? serveOrigin.x...serveOrigin.x
    }
}

public enum RallyPhase: Equatable, Sendable {
    /// 다음 서브까지 남은 시간
    case serving(remaining: TimeInterval)
    case rallying
    case over
}

/// 셔틀콕 랠리의 규칙. 화면, 마우스, 시계, 난수를 모두 밖에서 받아서 같은 입력이면 같은 결과가 나온다.
///
/// 캐릭터가 셔틀콕을 아래로 쳐 보내면 마우스 라켓으로 받아친다(1점). 라켓에 닿기만 하면 셔틀콕은 항상 캐릭터 높이까지 올라가고,
/// 라켓의 어느 쪽에 맞았는지에 따라 캐릭터가 달려갈 자리가 조금 달라진다. 캐릭터는 그 자리로 달려가 다시 아래로 쳐 보낸다.
/// 점수가 오를수록 게임 전체가 빨라진다. 목숨은 하나라서 셔틀콕을 놓치면 끝난다.
public struct RallyGame: Sendable {
    public static let gravity: CGFloat = 1400
    public static let racketRadius: CGFloat = 36
    public static let shuttleRadius: CGFloat = 8
    /// 목숨은 하나다. 한 번 놓치면 끝난다.
    public static let startingLives = 1
    public static let serveDelay: TimeInterval = 1
    /// 너무 낮은 곳에서 받아쳐도 최소한 이만큼 위가 캐릭터에게 닿을 높이로 본다.
    public static let minimumRise: CGFloat = 140
    /// 캐릭터가 셔틀콕을 받아치는 높이. 메뉴바 아래 이만큼 아래에서 친다.
    public static let returnHeightBelowCeiling: CGFloat = 25
    /// 받아칠 때 맞은 자리에서 좌우로 보낼 수 있는 최대 거리. 캐릭터가 달려서 닿을 수 있는 범위로 다시 줄어든다.
    public static let maxAimDistance: CGFloat = 480
    /// 라켓 가장자리에 맞았을 때 maxAimDistance의 이 비율만큼 보낸다.
    static let aimStrength: CGFloat = 0.8
    /// 난이도는 이 점수에서 최대가 된다.
    public static let maxDifficultyScore = 30
    /// 난이도가 최대일 때 게임 전체의 속도 배율
    public static let maxTimeScale: CGFloat = 1.8
    /// 캐릭터 높이에 확실히 닿도록 필요한 속도보다 이만큼 더 세게 올라간다.
    static let launchMargin: CGFloat = 1.05
    /// 캐릭터가 달리는 속도(pt/초). 점수가 오를수록 빨라진다.
    static let baseRunSpeed: CGFloat = 380
    static let extraRunSpeed: CGFloat = 150
    /// 달리는 중이라고 보는 최소 거리
    static let runningThreshold: CGFloat = 2
    static let landingMargin: CGFloat = 80
    static let wallMargin: CGFloat = 80

    public let court: RallyCourt
    public private(set) var shuttle: CGPoint
    public private(set) var velocity = CGVector.zero
    /// 캐릭터의 가로 위치와, 달려가고 있는 목표 위치. 목표는 셔틀콕이 올라와 닿을 자리다.
    public private(set) var characterX: CGFloat
    public private(set) var characterTargetX: CGFloat
    public private(set) var phase: RallyPhase = .serving(remaining: RallyGame.serveDelay)
    public private(set) var score = 0
    public private(set) var lives = RallyGame.startingLives
    public private(set) var combo = 0
    public private(set) var bestScore: Int
    /// 점수, 목숨, 단계가 바뀔 때마다 1씩 늘어난다. 점수판을 다시 그릴 때를 알려 준다.
    public private(set) var revision = 0

    /// 라켓으로 친 셔틀콕이 올라가는 중인지
    private enum ReturnPlan {
        case none
        /// 캐릭터가 달려가서 받아칠 차례를 기다린다.
        case character
    }

    private var returnPlan = ReturnPlan.none

    public init(court: RallyCourt, bestScore: Int = 0) {
        self.court = court
        self.bestScore = bestScore
        shuttle = court.serveOrigin
        characterX = court.serveOrigin.x
        characterTargetX = court.serveOrigin.x
    }

    public var isCharacterRunning: Bool {
        abs(characterX - characterTargetX) > Self.runningThreshold
    }

    /// 점수, 목숨, 최고 기록(최고 기록은 유지)을 처음으로 되돌리고 다시 서브한다.
    public mutating func restart() {
        score = 0
        lives = Self.startingLives
        combo = 0
        velocity = .zero
        shuttle = court.serveOrigin
        characterX = court.serveOrigin.x
        characterTargetX = court.serveOrigin.x
        returnPlan = .none
        phase = .serving(remaining: Self.serveDelay)
        revision += 1
    }

    public mutating func update(deltaTime: TimeInterval, racket: CGPoint, random: () -> Double) {
        // 점수가 오를수록 게임 전체가 빨라진다.
        let step = CGFloat(deltaTime) * timeScale
        runCharacter(step: step)

        switch phase {
        case .over:
            return
        case .serving(let remaining):
            let left = remaining - deltaTime * Double(timeScale)
            if left > 0 {
                phase = .serving(remaining: left)
            } else {
                shuttle = CGPoint(x: characterX, y: court.serveOrigin.y)
                hitDownward(random: random)
                phase = .rallying
                revision += 1
            }
        case .rallying:
            fly(step: step, racket: racket, random: random)
        }
    }

    /// 0(처음)에서 1(최고 난이도) 사이의 값
    var difficulty: CGFloat {
        CGFloat(min(score, Self.maxDifficultyScore)) / CGFloat(Self.maxDifficultyScore)
    }

    /// 게임 전체의 속도 배율. 1에서 시작해 난이도가 오르면 maxTimeScale까지 커진다.
    public var timeScale: CGFloat {
        1 + (Self.maxTimeScale - 1) * difficulty
    }

    /// 캐릭터가 셔틀콕을 받아치는 높이
    private var returnY: CGFloat {
        court.serveOrigin.y - Self.returnHeightBelowCeiling
    }

    private var runSpeed: CGFloat {
        Self.baseRunSpeed + difficulty * Self.extraRunSpeed
    }

    /// 캐릭터가 목표 위치를 향해 달린다.
    private mutating func runCharacter(step: CGFloat) {
        let distance = characterTargetX - characterX
        let reach = runSpeed * step
        characterX = abs(distance) <= reach ? characterTargetX : characterX + reach * (distance > 0 ? 1 : -1)
    }

    private mutating func fly(step: CGFloat, racket: CGPoint, random: () -> Double) {
        velocity.dy -= Self.gravity * step
        shuttle.x += velocity.dx * step
        shuttle.y += velocity.dy * step
        bounceOffWalls()

        switch returnPlan {
        case .character where shuttle.y >= returnY:
            // 캐릭터가 셔틀콕이 올라온 자리에서 받아친다.
            characterX = shuttle.x
            characterTargetX = shuttle.x
            returnPlan = .none
            hitDownward(random: random)
            return
        default:
            break
        }

        // 받아칠 차례가 아닐 때는 캐릭터가 셔틀콕의 가로 위치를 계속 따라 달린다.
        if returnPlan == .none {
            characterTargetX = clampedToCharacterRange(shuttle.x)
        }

        if returnPlan == .none, velocity.dy < 0, isHit(by: racket) {
            hitUpward(racket: racket)
        }

        if shuttle.y < court.bounds.minY - Self.shuttleRadius {
            missShuttle()
        }
    }

    private mutating func bounceOffWalls() {
        let minX = court.bounds.minX + Self.shuttleRadius
        let maxX = court.bounds.maxX - Self.shuttleRadius
        if shuttle.x < minX {
            shuttle.x = minX
            velocity.dx = abs(velocity.dx)
        } else if shuttle.x > maxX {
            shuttle.x = maxX
            velocity.dx = -abs(velocity.dx)
        }
    }

    private func isHit(by racket: CGPoint) -> Bool {
        hypot(shuttle.x - racket.x, shuttle.y - racket.y) <= Self.racketRadius + Self.shuttleRadius
    }

    private mutating func gainScore(_ points: Int) {
        score += points
        combo += 1
        bestScore = max(bestScore, score)
        revision += 1
    }

    /// 라켓에 닿으면 받아친다(1점). 셔틀콕은 항상 캐릭터 높이까지 올라간다.
    /// 마우스를 어떻게 움직였는지는 보지 않고, 라켓의 어느 쪽에 맞았는지로만 보낼 방향이 조금 달라진다.
    private mutating func hitUpward(racket: CGPoint) {
        gainScore(1)

        let reach = Self.racketRadius + Self.shuttleRadius
        let aim = max(-1, min(1, (shuttle.x - racket.x) / reach)) * Self.aimStrength

        let rise = max(Self.minimumRise, returnY - shuttle.y)
        velocity = CGVector(dx: 0, dy: (2 * Self.gravity * rise).squareRoot() * Self.launchMargin)
        planReturn(wantedX: shuttle.x + aim * Self.maxAimDistance)
        revision += 1
    }

    /// 캐릭터 높이에 닿는 자리를 정하고 셔틀콕이 그리로 가게 한다.
    /// 캐릭터가 달리는 범위 안이고, 올라오는 동안 달려서 닿을 수 있는 거리 안으로 끌어온다.
    private mutating func planReturn(wantedX: CGFloat) {
        let needed = returnY - shuttle.y
        let discriminant = velocity.dy * velocity.dy - 2 * Self.gravity * needed
        let time = needed <= 0 ? 0 : (velocity.dy - max(discriminant, 0).squareRoot()) / Self.gravity

        let runReach = runSpeed * time * 0.9
        let low = max(court.characterRange.lowerBound, characterX - runReach)
        let high = min(court.characterRange.upperBound, characterX + runReach)
        let arrivalX = low <= high ? max(low, min(high, wantedX)) : characterX
        if time > 0 {
            velocity.dx = (arrivalX - shuttle.x) / time
        }

        characterTargetX = arrivalX
        returnPlan = .character
    }

    private func clampedToCharacterRange(_ x: CGFloat) -> CGFloat {
        max(court.characterRange.lowerBound, min(court.characterRange.upperBound, x))
    }

    /// 캐릭터가 아래로 쳐 보낸다. 화면 아래쪽의 무작위 지점을 향하고, 점수가 오를수록 빠르고 넓게 퍼진다.
    private mutating func hitDownward(random: () -> Double) {
        let downSpeed = 120 + difficulty * 660
        let halfRange = min(court.bounds.width / 2 - Self.wallMargin, 160 + difficulty * 1000)
        let targetX = court.bounds.midX + CGFloat(random() * 2 - 1) * max(halfRange, 0)
        let landingY = court.bounds.minY + Self.landingMargin
        let drop = shuttle.y - landingY
        let flightTime = (-downSpeed + (downSpeed * downSpeed + 2 * Self.gravity * drop).squareRoot()) / Self.gravity
        velocity = CGVector(dx: (targetX - shuttle.x) / flightTime, dy: -downSpeed)
    }

    private mutating func resetForServe() {
        velocity = .zero
        shuttle = CGPoint(x: characterX, y: court.serveOrigin.y)
        returnPlan = .none
        revision += 1
    }

    private mutating func missShuttle() {
        lives -= 1
        combo = 0
        resetForServe()
        phase = lives > 0 ? .serving(remaining: Self.serveDelay) : .over
    }
}
