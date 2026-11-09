import Foundation

/// 대기 중인 캐릭터의 표정. 눈과 입 모양만 바뀌고 몸은 그대로다.
public enum EyeExpression: Equatable, Hashable, Sendable {
    case open
    case blink
    /// 마우스가 빠르게 움직일 때 눈이 휘둥그레진다.
    case wide
    /// 빠른 움직임이 계속되면 눈이 어긋나고 몸이 흔들린다. 번호는 두 모습을 번갈아 고른다.
    case dizzy(phase: Int)
    /// 오래 가만히 두면 눈을 감고 입을 벌렸다 닫는다.
    case yawn(phase: Int)

    public static let yawnPhaseCount = 6
}

/// 마우스 움직임과 시간 경과로 표정을 정한다. 시계와 난수를 밖에서 받아서 같은 입력이면 같은 결과가 나온다.
/// 우선순위는 어지러움, 놀람, 하품, 깜빡임, 평소 순이다.
public struct IdleBehavior: Sendable {
    /// 이 속도(pt/초) 이상으로 움직이면 빠른 움직임이다.
    public static let fastSpeed: Double = 1500
    /// 빠른 움직임이 멈춘 뒤 놀란 눈을 유지하는 시간
    public static let wideHold: TimeInterval = 0.4
    /// 빠른 움직임이 이만큼(초) 쌓이면 어지러워진다.
    public static let dizzyAfter: TimeInterval = 1.5
    /// 빠른 움직임이 멈춘 뒤 어지러움을 유지하는 시간
    public static let dizzyHold: TimeInterval = 1.8
    public static let dizzyStepInterval: TimeInterval = 0.2
    /// 이 시간(초) 동안 마우스가 가만히 있으면 하품한다.
    public static let yawnAfter: TimeInterval = 20
    public static let yawnStepInterval: TimeInterval = 0.25
    public static let blinkDuration: TimeInterval = 0.12
    /// 깜빡임 사이의 간격 범위(초)
    public static let blinkDelayRange: ClosedRange<Double> = 2.5...6
    /// 빠른 움직임 사이가 이보다 벌어지면 이어진 움직임으로 보지 않는다.
    private static let fastGap: TimeInterval = 0.3

    public private(set) var expression = EyeExpression.open

    private var lastMoveAt: TimeInterval
    private var lastFastAt: TimeInterval?
    private var fastDuration: TimeInterval = 0
    private var dizzyStartedAt: TimeInterval?
    private var yawnStartedAt: TimeInterval?
    private var hasYawned = false
    private var nextBlinkAt: TimeInterval
    private var blinkEndsAt: TimeInterval?

    public init(now: TimeInterval, blinkDelay: TimeInterval) {
        lastMoveAt = now
        nextBlinkAt = now + blinkDelay
    }

    /// 마우스가 움직였다. speed는 pt/초다.
    public mutating func mouseMoved(speed: Double, now: TimeInterval) {
        lastMoveAt = now
        yawnStartedAt = nil
        hasYawned = false
        guard speed >= Self.fastSpeed else { return }
        if let lastFastAt, now - lastFastAt <= Self.fastGap {
            fastDuration += now - lastFastAt
        }
        lastFastAt = now
    }

    /// 시간을 흘려 현재 표정을 돌려준다. nextBlinkDelay는 이번 깜빡임 다음의 간격이다.
    @discardableResult
    public mutating func tick(now: TimeInterval, nextBlinkDelay: TimeInterval) -> EyeExpression {
        expression = currentExpression(now: now, nextBlinkDelay: nextBlinkDelay)
        if expression != .open && expression != .blink {
            // 다른 표정이 끝난 직후에 바로 깜빡이지 않게 미룬다.
            nextBlinkAt = max(nextBlinkAt, now + 1)
        }
        return expression
    }

    private mutating func currentExpression(now: TimeInterval, nextBlinkDelay: TimeInterval) -> EyeExpression {
        if let phase = dizzyPhase(now: now) { return .dizzy(phase: phase) }

        if let lastFastAt, now - lastFastAt < Self.wideHold { return .wide }
        if let lastFastAt, now - lastFastAt > 1 { fastDuration = 0 }

        if let step = yawnStep(now: now) { return .yawn(phase: step) }

        if let blinkEndsAt, now < blinkEndsAt { return .blink }
        if now >= nextBlinkAt {
            blinkEndsAt = now + Self.blinkDuration
            nextBlinkAt = now + nextBlinkDelay
            return .blink
        }
        return .open
    }

    private mutating func dizzyPhase(now: TimeInterval) -> Int? {
        if dizzyStartedAt == nil, fastDuration >= Self.dizzyAfter {
            dizzyStartedAt = now
        }
        guard let startedAt = dizzyStartedAt, let lastFastAt else { return nil }
        guard now - lastFastAt < Self.dizzyHold else {
            dizzyStartedAt = nil
            fastDuration = 0
            return nil
        }
        return Int((now - startedAt) / Self.dizzyStepInterval) % 2
    }

    private mutating func yawnStep(now: TimeInterval) -> Int? {
        guard !hasYawned, now - lastMoveAt >= Self.yawnAfter else { return nil }
        let startedAt = yawnStartedAt ?? now
        yawnStartedAt = startedAt
        let step = Int((now - startedAt) / Self.yawnStepInterval)
        guard step < EyeExpression.yawnPhaseCount else {
            hasYawned = true
            yawnStartedAt = nil
            return nil
        }
        return step
    }
}
