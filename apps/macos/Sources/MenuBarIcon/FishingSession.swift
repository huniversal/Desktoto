import CoreGraphics
import Foundation

public enum FishingPhase: Equatable, Sendable {
    /// 줄을 드리우고 느긋하게 기다린다.
    case waiting
    /// 입질이 와서 낚싯대가 흔들린다.
    case biting
    /// 낚싯대를 휘어 물고기를 끌어올린다.
    case reeling
    /// 낚은 물고기를 잠깐 보여 준다.
    case showing
}

public enum FishingEyes: Equatable, Hashable, Sendable {
    case closed
    case open
    case wide
}

public enum RodPose: Equatable, Hashable, Sendable {
    case rest
    case up
    case down
    case bent
}

/// 쉬는 동안 메뉴바에서 하는 힐링 낚시의 흐름. 점수도 실패도 없이 기다림, 입질, 낚음, 보여 줌을 되풀이한다.
/// 시간과 난수를 밖에서 받아서 같은 입력이면 같은 결과가 나온다.
public struct FishingSession: Sendable {
    /// 다음 입질까지 기다리는 시간(초)의 범위
    public static let waitRange: ClosedRange<TimeInterval> = 4...9
    static let firstWait: TimeInterval = 2.5
    static let biteDuration: TimeInterval = 1.4
    static let reelDuration: TimeInterval = 0.8
    static let showDuration: TimeInterval = 2.0
    /// 낚싯대가 위아래로 바뀌는 간격
    static let shakeInterval: TimeInterval = 0.07
    /// 줄이 좌우로 한 칸씩 떨리는 간격
    static let wiggleInterval: TimeInterval = 0.06
    /// 다리가 까딱이는 간격
    static let legSwingInterval: TimeInterval = 1.4
    static let sparkleInterval: TimeInterval = 0.25
    public static let restLineLength: CGFloat = 4
    public static let reeledLineLength: CGFloat = 1

    public private(set) var phase = FishingPhase.waiting
    /// 지금 단계에 들어온 뒤 지난 시간(초)
    public private(set) var phaseTime: TimeInterval = 0
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var caughtCount = 0
    public private(set) var waitDuration = FishingSession.firstWait

    public init() {}

    public mutating func update(deltaTime: TimeInterval, random: () -> Double) {
        guard deltaTime > 0 else { return }
        elapsed += deltaTime
        phaseTime += deltaTime
        while phaseTime >= duration(of: phase) {
            phaseTime -= duration(of: phase)
            advance(random: random)
        }
    }

    private func duration(of phase: FishingPhase) -> TimeInterval {
        switch phase {
        case .waiting: return waitDuration
        case .biting: return Self.biteDuration
        case .reeling: return Self.reelDuration
        case .showing: return Self.showDuration
        }
    }

    private mutating func advance(random: () -> Double) {
        switch phase {
        case .waiting:
            phase = .biting
        case .biting:
            phase = .reeling
        case .reeling:
            phase = .showing
            caughtCount += 1
        case .showing:
            phase = .waiting
            let range = Self.waitRange
            waitDuration = range.lowerBound + (range.upperBound - range.lowerBound) * min(max(random(), 0), 1)
        }
    }

    // MARK: - 보여 줄 모습

    public var eyes: FishingEyes {
        switch phase {
        case .waiting: return .closed
        case .biting: return .open
        case .reeling, .showing: return .wide
        }
    }

    public var rodPose: RodPose {
        switch phase {
        case .waiting: return .rest
        case .biting: return Int(phaseTime / Self.shakeInterval).isMultiple(of: 2) ? .up : .down
        case .reeling, .showing: return .bent
        }
    }

    /// 낚싯대 끝에서 늘어진 줄의 길이(pt). 메뉴바 안에 머물도록 짧다. 끌어올리는 동안 줄어든다.
    public var lineLength: CGFloat {
        switch phase {
        case .waiting, .biting:
            return Self.restLineLength
        case .reeling:
            let progress = CGFloat(min(phaseTime / Self.reelDuration, 1))
            return (Self.restLineLength + (Self.reeledLineLength - Self.restLineLength) * progress).rounded()
        case .showing:
            return Self.reeledLineLength
        }
    }

    /// 입질할 때 줄이 옆으로 떨리는 칸 수(0 또는 1)
    public var lineWiggle: CGFloat {
        phase == .biting && !Int(phaseTime / Self.wiggleInterval).isMultiple(of: 2) ? 1 : 0
    }

    public var hasFish: Bool {
        phase == .reeling || phase == .showing
    }

    /// 입질을 알리는 느낌표를 보여 줄지
    public var isBubbleVisible: Bool {
        phase == .biting
    }

    public var isSparkling: Bool {
        phase == .showing && Int(phaseTime / Self.sparkleInterval).isMultiple(of: 2)
    }

    /// 앉아서 까딱이는 다리의 모양(0 또는 1)
    public var legSwing: Int {
        Int(elapsed / Self.legSwingInterval) % 2
    }

    /// 지금 그릴 모습. 같은 모습이면 이미지를 다시 만들거나 바꾸지 않아도 된다.
    public var frame: FishingFrame {
        FishingFrame(
            eyes: eyes,
            rod: rodPose,
            lineLength: Int(lineLength.rounded()),
            lineWiggle: Int(lineWiggle),
            hasFish: hasFish,
            hasBubble: isBubbleVisible,
            isSparkling: isSparkling,
            legSwing: legSwing
        )
    }
}

/// 낚시 중인 캐릭터의 한 모습. 메뉴바 이미지 하나에 해당한다.
public struct FishingFrame: Equatable, Hashable, Sendable {
    public let eyes: FishingEyes
    public let rod: RodPose
    public let lineLength: Int
    public let lineWiggle: Int
    public let hasFish: Bool
    public let hasBubble: Bool
    public let isSparkling: Bool
    public let legSwing: Int

    public init(eyes: FishingEyes, rod: RodPose, lineLength: Int, lineWiggle: Int, hasFish: Bool, hasBubble: Bool, isSparkling: Bool, legSwing: Int) {
        self.eyes = eyes
        self.rod = rod
        self.lineLength = lineLength
        self.lineWiggle = lineWiggle
        self.hasFish = hasFish
        self.hasBubble = hasBubble
        self.isSparkling = isSparkling
        self.legSwing = legSwing
    }
}
