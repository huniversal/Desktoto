import Testing
@testable import MenuBarIcon

@Test func scheduleRunsWhenSessionsRunOrFireworkPlays() {
    #expect(IconSchedule(isRunning: true, hasFirework: false, isSleeping: false) == .running)
    #expect(IconSchedule(isRunning: false, hasFirework: true, isSleeping: false) == .running)
    // 앱은 달리는 중이면 잠든 상태로 판정하지 않지만, 겹쳐도 달리기가 먼저다.
    #expect(IconSchedule(isRunning: true, hasFirework: false, isSleeping: true) == .running)
}

@Test func scheduleSleepsOnlyWhenNothingElseIsHappening() {
    #expect(IconSchedule(isRunning: false, hasFirework: false, isSleeping: true) == .sleeping)
    #expect(IconSchedule(isRunning: false, hasFirework: false, isSleeping: false) == .still)
}

@Test func scheduleIntervalsMatchOriginal() {
    #expect(IconSchedule.running.interval == 1.0 / 24.0)
    #expect(IconSchedule.sleeping.interval == 0.6)
    #expect(IconSchedule.still.interval == nil)
}

@Test func runningTicksAdvanceOnePhaseAndLoopBack() {
    var animation = IconAnimation()

    let first = animation.tickRunning(isRunning: true)
    #expect(first == RunningTick(frame: .running(phase: 1), fireworkFrame: nil, shouldStop: false))

    var last = first
    (1..<IconTiming.runningFrameCount).forEach { _ in last = animation.tickRunning(isRunning: true) }
    #expect(last.frame == .running(phase: 0))
}

@Test func tickShowsStandingWhenNoSessionRuns() {
    var animation = IconAnimation()

    #expect(animation.tickRunning(isRunning: false).frame == .standing)
}

@Test func fireworkPlaysAllFramesThenStopsWhenNothingRuns() {
    var animation = IconAnimation()
    animation.startFirework()
    #expect(animation.hasFirework)

    let ticks = (0..<IconTiming.fireworkFrameCount).map { _ in animation.tickRunning(isRunning: false) }

    #expect(ticks.map(\.fireworkFrame) == (0..<IconTiming.fireworkFrameCount).map { $0 })
    #expect(ticks.dropLast().allSatisfy { !$0.shouldStop })
    #expect(ticks.last?.shouldStop == true)
    #expect(!animation.hasFirework)
    #expect(animation.tickRunning(isRunning: false) == RunningTick(frame: .standing, fireworkFrame: nil, shouldStop: false))
}

@Test func fireworkEndKeepsTheTimerWhileSessionsStillRun() {
    var animation = IconAnimation()
    animation.startFirework()

    let ticks = (0..<IconTiming.fireworkFrameCount).map { _ in animation.tickRunning(isRunning: true) }

    #expect(ticks.allSatisfy { !$0.shouldStop })
    #expect(!animation.hasFirework)
}

@Test func sleepingTicksCycleSixFramesAndResetOnWake() {
    var animation = IconAnimation()
    #expect(animation.currentSleepingFrame == .sleeping(frame: 0))

    let frames = (0..<IconTiming.sleepFrameCount).map { _ in animation.tickSleeping() }
    #expect(frames == [1, 2, 3, 4, 5, 0].map { IconFrame.sleeping(frame: $0) })

    _ = animation.tickSleeping()
    animation.resetSleeping()
    #expect(animation.sleepFrame == 0)
}
