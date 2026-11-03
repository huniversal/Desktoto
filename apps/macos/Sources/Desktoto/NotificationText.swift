import Domain

/// 알림 제목과 본문. 소리와 전송은 앱이 한다.
enum NotificationText {
    static let maxTitleLength = 40
    static let finishedBody = "작업이 끝났어요"

    /// 세션 제목, 없으면 프로젝트 이름, 둘 다 모르면 "AI"
    static func title(for session: SessionInfo?) -> String {
        let sessionTitle = session?.title.flatMap { $0.isEmpty ? nil : $0 }
        return truncated(sessionTitle ?? session?.projectName ?? "AI")
    }

    static func waitingBody(for kind: WaitingKind) -> String {
        kind == .question ? "답변이 필요해요" : "승인이 필요해요"
    }

    static func truncated(_ text: String, maxLength: Int = maxTitleLength) -> String {
        text.count > maxLength ? "\(text.prefix(maxLength))…" : text
    }
}
