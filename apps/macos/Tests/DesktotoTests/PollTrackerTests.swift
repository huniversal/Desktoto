import Domain
import Testing
@testable import Desktoto

struct PollTrackerTests {
    @Test func 진행_중이던_세션이_완료되면_완료로_판정한다() {
        var tracker = PollTracker()
        _ = tracker.advance(states: ["a": .running], waitingKinds: [:])

        let result = tracker.advance(states: ["a": .completed], waitingKinds: [:])

        #expect(result.finishedIDs == ["a"])
    }

    @Test func 처음부터_완료인_세션은_완료로_보지_않는다() {
        var tracker = PollTracker()

        let result = tracker.advance(states: ["a": .completed], waitingKinds: [:])

        #expect(result.finishedIDs.isEmpty)
    }

    @Test func 시간이_지나_만료된_세션은_완료로_보지_않는다() {
        var tracker = PollTracker()
        _ = tracker.advance(states: ["a": .running], waitingKinds: [:])

        let result = tracker.advance(states: ["a": .idle], waitingKinds: [:])

        #expect(result.finishedIDs.isEmpty)
    }

    @Test func 질문을_남기고_끝난_세션은_완료가_아니라_대기로만_다룬다() {
        var tracker = PollTracker()
        _ = tracker.advance(states: ["a": .running], waitingKinds: [:])

        let result = tracker.advance(states: ["a": .completed], waitingKinds: ["a": .question])

        #expect(result.finishedIDs.isEmpty)
        #expect(result.newWaitingKinds == ["a": .question])
    }

    @Test func 완료는_한_번만_알린다() {
        var tracker = PollTracker()
        _ = tracker.advance(states: ["a": .running], waitingKinds: [:])
        _ = tracker.advance(states: ["a": .completed], waitingKinds: [:])

        let result = tracker.advance(states: ["a": .completed], waitingKinds: [:])

        #expect(result.finishedIDs.isEmpty)
    }

    @Test func 새로_대기하게_된_세션만_알리고_계속_대기하면_반복하지_않는다() {
        var tracker = PollTracker()

        let first = tracker.advance(states: ["a": .running], waitingKinds: ["a": .approval])
        let second = tracker.advance(states: ["a": .running], waitingKinds: ["a": .approval])

        #expect(first.newWaitingKinds == ["a": .approval])
        #expect(second.newWaitingKinds.isEmpty)
    }

    @Test func 대기가_풀렸다가_다시_걸리면_다시_알린다() {
        var tracker = PollTracker()
        _ = tracker.advance(states: ["a": .running], waitingKinds: ["a": .approval])
        _ = tracker.advance(states: ["a": .running], waitingKinds: [:])

        let result = tracker.advance(states: ["a": .running], waitingKinds: ["a": .approval])

        #expect(result.newWaitingKinds == ["a": .approval])
    }

    @Test func 대기_중인_세션은_달리는_개수에서_뺀다() {
        var tracker = PollTracker()

        let result = tracker.advance(
            states: ["a": .running, "b": .running, "c": .idle],
            waitingKinds: ["b": .approval]
        )

        #expect(result.runningCount == 1)
        #expect(result.isWaiting)
    }

    @Test func 세션이_없으면_대기도_달리기도_없다() {
        var tracker = PollTracker()

        let result = tracker.advance(states: [:], waitingKinds: [:])

        #expect(result == PollResult(finishedIDs: [], newWaitingKinds: [:], runningCount: 0, isWaiting: false))
    }

    @Test func 완료_id는_정렬된_순서로_돌려준다() {
        var tracker = PollTracker()
        _ = tracker.advance(states: ["c": .running, "a": .running, "b": .running], waitingKinds: [:])

        let result = tracker.advance(states: ["c": .completed, "a": .completed, "b": .completed], waitingKinds: [:])

        #expect(result.finishedIDs == ["a", "b", "c"])
    }
}
