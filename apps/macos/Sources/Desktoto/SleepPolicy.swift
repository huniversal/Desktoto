import Foundation
import MenuBarIcon

/// 마지막 활동(달리기, 응답 대기, 완료, 캐릭터 클릭) 뒤 일정 시간이 지나면 쉰다. 쉴 때는 졸음, 낚시, 스파클라 같은 여러 일 중 하나를 하고, 무엇을 할지는 쉬기 시작할 때 한 번 정한다. 직전에 한 일은 건너뛴다.
/// 시작할 때도 활동이 없으면 그때부터 센다.
struct SleepPolicy: Equatable {
    static let defaultIdleSeconds: TimeInterval = 120
    static let environmentKey = "AIRUN_SLEEP_AFTER"

    let idleSeconds: TimeInterval
    private var lastActiveAt: Date
    private var currentRest: IconRest?
    /// 직전에 쉬면서 한 일. 깨어난 뒤에도 기억해서 연달아 같은 일이 나오지 않게 한다.
    private var lastRest: IconRest?

    init(startedAt: Date, idleSeconds: TimeInterval = defaultIdleSeconds) {
        self.idleSeconds = idleSeconds
        lastActiveAt = startedAt
    }

    /// 확인용으로 환경 변수(초)로 바꿀 수 있다. 숫자가 아니거나 nan, inf처럼 유한하지 않으면 기본값을 쓴다.
    static func idleSeconds(environment: [String: String]) -> TimeInterval {
        guard let text = environment[environmentKey],
              let value = Double(text),
              value.isFinite
        else { return defaultIdleSeconds }
        return value
    }

    /// 캐릭터를 눌렀다. 쉬던 중이면 깨고, 기준 시간을 처음부터 다시 센다.
    mutating func noteClick(now: Date) {
        lastActiveAt = now
        currentRest = nil
    }

    /// 지금 쉬어야 하는지와, 쉰다면 무엇을 하는지를 돌려준다. 쉬는 동안에는 같은 일을 계속하고, 깼다가 다시 쉬면 새로 고른다.
    mutating func rest(now: Date, isBusy: Bool, hasFinished: Bool, hasFirework: Bool, random: () -> Double) -> IconRest? {
        guard isSleeping(now: now, isBusy: isBusy, hasFinished: hasFinished, hasFirework: hasFirework) else {
            currentRest = nil
            return nil
        }
        if currentRest == nil {
            let candidates = IconRest.allCases.filter { $0 != lastRest }
            let ratio = min(max(random(), 0), 1)
            let index = min(Int(ratio * Double(candidates.count)), candidates.count - 1)
            currentRest = candidates[index]
            lastRest = currentRest
        }
        return currentRest
    }

    /// 달리거나 응답을 기다리는 중이거나 방금 끝났으면 활동 시각을 갱신하고, 지금 잠들어야 하는지 돌려준다.
    /// 잠듦 조건에는 방금 끝남을 넣지 않는다(원본과 같다). 폭죽이 재생 중이면 잠들지 않는다.
    mutating func isSleeping(now: Date, isBusy: Bool, hasFinished: Bool, hasFirework: Bool) -> Bool {
        if isBusy || hasFinished { lastActiveAt = now }
        return !isBusy && !hasFirework && now.timeIntervalSince(lastActiveAt) >= idleSeconds
    }
}
