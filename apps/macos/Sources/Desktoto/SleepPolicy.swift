import Foundation

/// 마지막 활동(달리기, 응답 대기, 완료) 뒤 일정 시간이 지나면 잠든다. 시작할 때도 활동이 없으면 그때부터 센다.
struct SleepPolicy: Equatable {
    static let defaultIdleSeconds: TimeInterval = 600
    static let environmentKey = "AIRUN_SLEEP_AFTER"

    let idleSeconds: TimeInterval
    private var lastActiveAt: Date

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

    /// 달리거나 응답을 기다리는 중이거나 방금 끝났으면 활동 시각을 갱신하고, 지금 잠들어야 하는지 돌려준다.
    /// 잠듦 조건에는 방금 끝남을 넣지 않는다(원본과 같다). 폭죽이 재생 중이면 잠들지 않는다.
    mutating func isSleeping(now: Date, isBusy: Bool, hasFinished: Bool, hasFirework: Bool) -> Bool {
        if isBusy || hasFinished { lastActiveAt = now }
        return !isBusy && !hasFirework && now.timeIntervalSince(lastActiveAt) >= idleSeconds
    }
}
