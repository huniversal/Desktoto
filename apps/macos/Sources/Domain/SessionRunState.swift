/// completed: 응답이 정상 종료됨(완료 알림 대상).
/// idle: 그 외 대기. 진행 중이던 세션이 시간이 지나 만료된 경우도 idle이라 알림 대상이 아니다.
public enum SessionRunState: Sendable, Equatable {
    case running
    case completed
    case idle
}

/// 사람의 응답을 기다리는 이유. approval은 도구 사용이나 계획 승인, question은 질문에 대한 답이다.
public enum WaitingKind: Sendable, Equatable {
    case approval
    case question
}
