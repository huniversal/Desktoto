import Domain

/// 폴링 한 번의 판정 결과.
struct PollResult: Equatable {
    /// 이번 틱에 새로 완료된 세션 id (정렬된 순서)
    let finishedIDs: [String]
    /// 이번 틱에 새로 응답을 기다리게 된 세션과 이유
    let newWaitingKinds: [String: WaitingKind]
    /// 응답을 기다리는 세션은 뺀, 달리는 세션 수
    let runningCount: Int
    /// 응답을 기다리는 세션이 하나라도 있는지
    let isWaiting: Bool
}

/// 이전 틱과 비교해 완료와 새 대기를 판정한다. 시간과 파일은 모른다.
struct PollTracker {
    private var previousStates: [String: SessionRunState] = [:]
    private var previousWaitingIDs: Set<String> = []

    /// 진행 중이던 세션이 정상 종료(completed)되었을 때만 완료로 본다. 시간이 지나 만료된(idle) 세션은 알리지 않는다.
    /// 질문을 남기고 끝난 세션은 답을 기다리는 상황이라서 완료가 아니라 대기로만 다룬다.
    mutating func advance(states: [String: SessionRunState], waitingKinds: [String: WaitingKind]) -> PollResult {
        let waitingIDs = Set(waitingKinds.keys)
        let finishedIDs = states
            .filter { $0.value == .completed && previousStates[$0.key] == .running && !waitingIDs.contains($0.key) }
            .map(\.key)
            .sorted()
        let newWaitingIDs = waitingIDs.subtracting(previousWaitingIDs)

        previousStates = states
        previousWaitingIDs = waitingIDs

        return PollResult(
            finishedIDs: finishedIDs,
            newWaitingKinds: waitingKinds.filter { newWaitingIDs.contains($0.key) },
            // 사람의 응답(승인, 답변)을 기다리는 세션은 진행 중이 아니라서 달리는 개수에서 뺀다.
            runningCount: states.filter { $0.value == .running && !waitingIDs.contains($0.key) }.count,
            isWaiting: !waitingIDs.isEmpty
        )
    }
}
