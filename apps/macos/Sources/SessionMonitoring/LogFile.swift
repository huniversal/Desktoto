import Domain
import Foundation

/// 기록 파일의 수정 시각은 실제 작업 시각이 아니다. 세션을 다시 열거나 백그라운드 명령이 끝나면 앱이 줄을 덧붙여서,
/// 몇 시간 전에 끝난 세션의 수정 시각이 방금으로 바뀌기도 한다. 그래서 기록 안의 작업 기록과 그 시각으로 따로 판단한다.
enum LogOutcome: Sendable, Equatable {
    /// 마지막 작업이 정상 종료됨
    case completed
    /// 중단되었거나 판단할 기록이 없음
    case stopped
    /// 마지막 작업이 아직 끝나지 않음
    case inProgress
}

struct ActivitySnapshot: Sendable, Equatable {
    let lastActivity: Date
    let outcome: LogOutcome
}

struct LogFile: Sendable, Equatable {
    let url: URL
    let modifiedAt: Date
    let tool: AiTool
    /// 기록 안의 시각으로 본 마지막 실제 활동 시각
    let activity: Date
    let outcome: LogOutcome

    /// 기록 파일 이름이 곧 세션 고유 id다.
    var id: String { url.deletingPathExtension().lastPathComponent }
}
