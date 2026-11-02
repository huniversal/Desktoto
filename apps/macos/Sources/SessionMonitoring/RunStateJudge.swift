import Domain
import Foundation

enum RunStateJudge {
    static func runState(for file: LogFile, now: Date) -> SessionRunState {
        switch file.outcome {
        case .completed:
            return .completed
        case .stopped:
            return .idle
        case .inProgress:
            // 긴 응답 생성이나 빌드처럼 기록이 한동안 없을 수 있으므로 넉넉한 시간 안에서만 진행 중으로 본다.
            // 중단(Esc)되거나 창이 닫혀서 시간이 지난 경우는 완료가 아니라 대기(idle)로 둔다.
            let window = file.tool == .codex
                ? SessionMonitoringPolicy.activeWindow
                : SessionMonitoringPolicy.claudePendingWindow
            return now.timeIntervalSince(file.activity) < window ? .running : .idle
        }
    }
}
