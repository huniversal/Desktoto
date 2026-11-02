import Foundation
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
        #expect(SleepPolicy.idleSeconds(environment: [:]) == 600)
        #expect(SleepPolicy.idleSeconds(environment: ["AIRUN_SLEEP_AFTER": "abc"]) == 600)
    }
}
