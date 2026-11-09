import Foundation
import MenuBarIcon
import Testing
@testable import Desktoto

struct SleepPolicyTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func 활동이_없어도_기준_시간_전에는_잠들지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 600)

        let isSleeping = policy.isSleeping(now: start.addingTimeInterval(599), isBusy: false, hasFinished: false, hasFirework: false)

        #expect(!isSleeping)
    }

    @Test func 시작_때부터_센다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 600)

        let isSleeping = policy.isSleeping(now: start.addingTimeInterval(600), isBusy: false, hasFinished: false, hasFirework: false)

        #expect(isSleeping)
    }

    @Test func 활동이_있으면_시각을_갱신해서_다시_센다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 600)
        _ = policy.isSleeping(now: start.addingTimeInterval(500), isBusy: true, hasFinished: false, hasFirework: false)

        let isSleepingBefore = policy.isSleeping(now: start.addingTimeInterval(1_000), isBusy: false, hasFinished: false, hasFirework: false)
        let isSleepingAfter = policy.isSleeping(now: start.addingTimeInterval(1_100), isBusy: false, hasFinished: false, hasFirework: false)

        #expect(!isSleepingBefore)
        #expect(isSleepingAfter)
    }

    @Test func 활동_중이면_잠들지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 0)

        let isSleeping = policy.isSleeping(now: start.addingTimeInterval(10), isBusy: true, hasFinished: false, hasFirework: false)

        #expect(!isSleeping)
    }

    @Test func 방금_끝난_틱은_활동_시각만_갱신하고_잠듦_조건에는_넣지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 0)

        let isSleeping = policy.isSleeping(now: start.addingTimeInterval(10), isBusy: false, hasFinished: true, hasFirework: false)
        let isSleepingLater = policy.isSleeping(now: start.addingTimeInterval(20), isBusy: false, hasFinished: false, hasFirework: false)

        #expect(isSleeping)
        #expect(isSleepingLater)
    }

    @Test func 방금_끝나면_기준_시간을_처음부터_다시_센다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 600)
        _ = policy.isSleeping(now: start.addingTimeInterval(500), isBusy: false, hasFinished: true, hasFirework: false)

        let isSleeping = policy.isSleeping(now: start.addingTimeInterval(1_000), isBusy: false, hasFinished: false, hasFirework: false)

        #expect(!isSleeping)
    }

    @Test func 폭죽이_재생_중이면_잠들지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 600)

        let isSleeping = policy.isSleeping(now: start.addingTimeInterval(700), isBusy: false, hasFinished: false, hasFirework: true)

        #expect(!isSleeping)
    }

    @Test func 환경_변수로_시간을_바꾼다() {
        #expect(SleepPolicy.idleSeconds(environment: ["AIRUN_SLEEP_AFTER": "5"]) == 5)
    }

    @Test func 환경_변수가_없거나_숫자가_아니면_기본값이다() {
        #expect(SleepPolicy.idleSeconds(environment: [:]) == 120)
        #expect(SleepPolicy.idleSeconds(environment: ["AIRUN_SLEEP_AFTER": "abc"]) == 120)
    }

    @Test func 환경_변수가_유한한_숫자가_아니면_기본값을_쓴다() {
        for text in ["nan", "inf", "-inf", "infinity", "abc", ""] {
            let seconds = SleepPolicy.idleSeconds(environment: [SleepPolicy.environmentKey: text])

            #expect(seconds == SleepPolicy.defaultIdleSeconds)
        }
        #expect(SleepPolicy.idleSeconds(environment: [SleepPolicy.environmentKey: "5"]) == 5)
        #expect(SleepPolicy.idleSeconds(environment: [:]) == SleepPolicy.defaultIdleSeconds)
    }

    // MARK: 쉬는 일과 캐릭터 클릭

    private func rest(_ policy: inout SleepPolicy, at seconds: TimeInterval, isBusy: Bool = false, random: Double) -> IconRest? {
        policy.rest(now: start.addingTimeInterval(seconds), isBusy: isBusy, hasFinished: false, hasFirework: false, random: { random })
    }

    @Test func 기본_기준_시간은_2분이다() {
        #expect(SleepPolicy.defaultIdleSeconds == 120)
    }

    @Test func 쉬기_시작할_때_난수로_여러_일_중_하나를_고른다() {
        var first = SleepPolicy(startedAt: start, idleSeconds: 180)
        var second = SleepPolicy(startedAt: start, idleSeconds: 180)
        var third = SleepPolicy(startedAt: start, idleSeconds: 180)

        #expect(rest(&first, at: 200, random: 0) == .sleeping)
        #expect(rest(&second, at: 200, random: 0.15) == .fishing)
        #expect(rest(&third, at: 200, random: 0.99) == .bubbles)
    }

    @Test func 모든_쉬는_일이_고를_수_있는_난수_범위에_있다() {
        let chosen = stride(from: 0.0, through: 1.0, by: 0.01).map { value -> IconRest? in
            var policy = SleepPolicy(startedAt: start, idleSeconds: 180)
            return rest(&policy, at: 200, random: value)
        }

        #expect(Set(chosen.compactMap { $0 }) == Set(IconRest.allCases))
    }

    @Test func 기준_시간_전에는_쉬지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 180)

        #expect(rest(&policy, at: 179, random: 0.15) == nil)
    }

    @Test func 쉬는_동안에는_같은_일을_계속한다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 180)
        let first = rest(&policy, at: 200, random: 0.15)

        let second = rest(&policy, at: 260, random: 0.99)

        #expect(first == .fishing)
        #expect(second == .fishing)
    }

    @Test func 캐릭터를_누르면_깨고_기준_시간을_처음부터_다시_센다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 180)
        _ = rest(&policy, at: 200, random: 0.15)

        policy.noteClick(now: start.addingTimeInterval(210))
        let justAfter = rest(&policy, at: 211, random: 0.15)
        let almost = rest(&policy, at: 210 + 179, random: 0.15)
        let later = rest(&policy, at: 210 + 181, random: 0.99)

        #expect(justAfter == nil)
        #expect(almost == nil)
        #expect(later == .bubbles)
    }

    @Test func 깼다가_다시_쉬면_새로_고른다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 180)
        let first = rest(&policy, at: 200, random: 0.15)
        _ = rest(&policy, at: 210, isBusy: true, random: 0.15)

        let again = rest(&policy, at: 210 + 181, random: 0.99)

        #expect(first == .fishing)
        #expect(again == .bubbles)
    }

    @Test func 직전에_한_일은_건너뛴다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 180)
        let first = rest(&policy, at: 200, random: 0.15)
        policy.noteClick(now: start.addingTimeInterval(210))

        // 같은 난수여도 직전의 낚시를 뺀 목록에서 고르므로 다른 일이 나온다.
        let second = rest(&policy, at: 210 + 181, random: 0.15)

        #expect(first == .fishing)
        #expect(second != nil)
        #expect(second != first)
    }

    @Test func 연달아_쉬어도_같은_일이_두_번_이어지지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 180)
        var previous: IconRest?
        var clock: TimeInterval = 0
        for index in 0..<200 {
            clock += 200
            let value = Double(index % 17) / 16
            let current = rest(&policy, at: clock, random: value)
            #expect(current != nil)
            #expect(current != previous)
            previous = current
            policy.noteClick(now: start.addingTimeInterval(clock + 1))
        }
    }

    @Test func 작업_중이거나_폭죽이_재생_중이면_쉬지_않는다() {
        var policy = SleepPolicy(startedAt: start, idleSeconds: 0)

        let busy = rest(&policy, at: 10, isBusy: true, random: 0.15)
        let firework = policy.rest(now: start.addingTimeInterval(20), isBusy: false, hasFinished: false, hasFirework: true, random: { 0.15 })

        #expect(busy == nil)
        #expect(firework == nil)
    }
}
