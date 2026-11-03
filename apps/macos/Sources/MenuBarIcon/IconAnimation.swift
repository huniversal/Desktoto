import Foundation

/// 지금 상태에서 어떤 주기로 이미지를 바꿔야 하는지. 타이머를 만들고 멈추는 일은 앱이 한다.
public enum IconSchedule: Equatable, Sendable {
    /// 달리기 주기로 갱신한다. 달리는 세션이 있거나 폭죽이 재생 중일 때다.
    case running
    /// 잠듦 주기로 z를 바꾼다.
    case sleeping
    /// 타이머 없이 서 있는 모습을 보여 준다.
    case still

    public init(isRunning: Bool, hasFirework: Bool, isSleeping: Bool) {
        if isRunning || hasFirework {
            self = .running
        } else if isSleeping {
            self = .sleeping
        } else {
            self = .still
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .running: return IconTiming.runningFrameInterval
        case .sleeping: return IconTiming.sleepFrameInterval
        case .still: return nil
        }
    }
}

/// 달리기 타이머 한 번의 결과.
public struct RunningTick: Equatable, Sendable {
    /// 보여 줄 바탕 모습. 달리는 세션이 없으면 서 있는 모습이다.
    public let frame: IconFrame
    /// 바탕 뒤에 합성할 폭죽 프레임. 재생 중이 아니면 nil이다.
    public let fireworkFrame: Int?
    /// 폭죽이 끝났고 달리는 세션도 없어서 타이머를 멈추고 서 있는 모습으로 돌아가야 하는지.
    public let shouldStop: Bool
}

/// 달리기, 잠듦, 폭죽의 프레임 번호를 한 칸씩 진행한다. 시간과 타이머는 모른다.
public struct IconAnimation: Equatable, Sendable {
    public private(set) var runningPhase = 0
    public private(set) var sleepFrame = 0
    public private(set) var fireworkFrame: Int?

    public init() {}

    public var hasFirework: Bool {
        fireworkFrame != nil
    }

    public mutating func startFirework() {
        fireworkFrame = 0
    }

    public mutating func tickRunning(isRunning: Bool) -> RunningTick {
        runningPhase = (runningPhase + 1) % IconTiming.runningFrameCount
        let frame: IconFrame = isRunning ? .running(phase: runningPhase) : .standing

        guard let currentFirework = fireworkFrame else {
            return RunningTick(frame: frame, fireworkFrame: nil, shouldStop: false)
        }
        let nextFirework = currentFirework + 1 < IconTiming.fireworkFrameCount ? currentFirework + 1 : nil
        fireworkFrame = nextFirework
        return RunningTick(frame: frame, fireworkFrame: currentFirework, shouldStop: nextFirework == nil && !isRunning)
    }

    /// 잠듦 타이머를 처음 켤 때 먼저 보여 줄 모습
    public var currentSleepingFrame: IconFrame {
        .sleeping(frame: sleepFrame)
    }

    public mutating func tickSleeping() -> IconFrame {
        sleepFrame = (sleepFrame + 1) % IconTiming.sleepFrameCount
        return currentSleepingFrame
    }

    /// 잠에서 깨면 z가 처음부터 다시 떠오른다.
    public mutating func resetSleeping() {
        sleepFrame = 0
    }
}
