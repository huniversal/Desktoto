import Boundaries
import Foundation

/// Claude Code의 Notification(permission_prompt) hook이 `~/.ai-run/waiting/<세션 id>`에 남긴 승인 요청 시각을 읽는다.
struct WaitingSignalReader: Sendable {
    let fileSystem: any FileSystem

    /// 승인을 요청한 시각. 파일 내용이 시각(초)이면 그 값을, 아니면 파일 수정 시각을 쓴다. 파일이 없으면 nil이다.
    func requestedAt(sessionID: String) -> Date? {
        let url = fileSystem.homeDirectory.appendingPathComponent(".ai-run/waiting/\(sessionID)")
        guard let data = fileSystem.readAll(of: url),
              let text = String(data: data, encoding: .utf8) else { return nil }
        if let seconds = TimeInterval(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Date(timeIntervalSince1970: seconds)
        }
        return fileSystem.modificationDate(of: url)
    }

    /// 신호가 만료되지 않았고, 요청 뒤에 새 대화 기록이 없으면 승인을 기다리는 중이다.
    /// 승인하거나 거부하면 도구 결과 같은 대화 기록이 새로 쌓이므로, 그 시각보다 새 기록이 있으면 이미 처리된 것으로 본다.
    /// lastConversationAt은 필요할 때만 호출한다.
    func isWaiting(sessionID: String, now: Date, lastConversationAt: () -> Date?) -> Bool {
        guard let requestedAt = requestedAt(sessionID: sessionID),
              now.timeIntervalSince(requestedAt) < SessionMonitoringPolicy.waitingMaxAge else { return false }
        if let lastRecordAt = lastConversationAt(), lastRecordAt > requestedAt { return false }
        return true
    }
}
