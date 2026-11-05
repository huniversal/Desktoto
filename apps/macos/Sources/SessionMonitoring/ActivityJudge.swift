import Boundaries
import Domain
import Foundation

/// 기록에서 마지막 실제 활동 시각과 작업 결과를 판정한다. 입출력이 없는 순수 함수다.
enum ActivityJudge {
    /// records는 최신순이다. 판단할 기록이 없으면 nil이다.
    static func snapshot(records: [JSONValue], tool: AiTool, modifiedAt: Date) -> ActivitySnapshot? {
        switch tool {
        case .claude: claudeSnapshot(records: records, modifiedAt: modifiedAt)
        case .codex: codexSnapshot(records: records, modifiedAt: modifiedAt)
        // Antigravity는 기록 파일이 아니라 SQLite로 판정한다(AntigravityReader).
        case .antigravity: nil
        }
    }

    private static func claudeSnapshot(records: [JSONValue], modifiedAt: Date) -> ActivitySnapshot? {
        guard let conversation = records.first(where: {
                  SessionMonitoringPolicy.claudeConversationTypes.contains($0["type"]?.stringValue ?? "")
              }),
              let latest = records.first else { return nil }
        let isEnded = conversation["type"]?.stringValue == "assistant"
            && isEndTurn(stopReason: conversation["message"]?["stop_reason"]?.stringValue)
        return ActivitySnapshot(
            lastActivity: RecordTimestamp.date(of: latest, fallback: modifiedAt),
            outcome: isEnded ? .completed : .inProgress
        )
    }

    private static func codexSnapshot(records: [JSONValue], modifiedAt: Date) -> ActivitySnapshot? {
        guard let lifecycle = records.first(where: {
                  SessionMonitoringPolicy.codexLifecycleTypes.contains($0["payload"]?["type"]?.stringValue ?? "")
              }),
              let latest = records.first else { return nil }
        switch lifecycle["payload"]?["type"]?.stringValue {
        case "task_complete":
            return ActivitySnapshot(lastActivity: RecordTimestamp.date(of: lifecycle, fallback: modifiedAt), outcome: .completed)
        case "turn_aborted":
            return ActivitySnapshot(lastActivity: RecordTimestamp.date(of: lifecycle, fallback: modifiedAt), outcome: .stopped)
        default:
            return ActivitySnapshot(lastActivity: RecordTimestamp.date(of: latest, fallback: modifiedAt), outcome: .inProgress)
        }
    }

    /// 턴이 정상 종료됐음을 나타내는 stop_reason인지.
    static func isEndTurn(stopReason: String?) -> Bool {
        stopReason == "end_turn" || stopReason == "stop_sequence"
    }
}
