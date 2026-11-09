import Foundation

/// 쉬는 동안 하는 일. 3분 동안 캐릭터를 누르지 않으면 이 중 하나를 고른다.
public enum IconRest: String, CaseIterable, Equatable, Sendable {
    case sleeping
    case fishing
    case sparkler
    case music
    case drink
    case stargazing
    case rain
    case bubbles
}

/// 시간 순서대로 모습이 정해진 쉬는 일의 한 장면. 같은 장면이면 이미지를 다시 만들지 않는다.
public struct RestFrame: Equatable, Hashable, Sendable {
    public let activity: IconRest
    public let step: Int

    public init(activity: IconRest, step: Int) {
        self.activity = activity
        self.step = step
    }
}

/// 졸음과 낚시를 뺀 쉬는 일은 정해진 장면을 한 칸씩 되풀이한다. 시간만 알면 지금 장면이 정해진다.
public enum RestTimeline {
    /// 장면이 한 칸 넘어가는 시간. 천천히 움직여서 차분하게 보이고 메뉴바 갱신도 적다.
    public static let stepInterval: TimeInterval = 0.2

    /// 한 바퀴의 장면 수. 졸음과 낚시는 따로 움직여서 nil이다.
    public static func cycleSteps(for activity: IconRest) -> Int? {
        switch activity {
        case .sleeping, .fishing: return nil
        case .sparkler: return 40
        case .music: return 16
        case .drink: return 24
        case .stargazing: return 40
        case .rain: return 8
        case .bubbles: return 40
        }
    }

    /// 쉬기 시작한 뒤 elapsed초가 지났을 때의 장면
    public static func frame(activity: IconRest, elapsed: TimeInterval) -> RestFrame? {
        guard let count = cycleSteps(for: activity) else { return nil }
        let step = Int(max(elapsed, 0) / stepInterval) % count
        return RestFrame(activity: activity, step: step)
    }
}
