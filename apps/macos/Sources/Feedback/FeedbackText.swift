import Foundation

// 입력 창에 보이는 문구.
public enum FeedbackText {
    public static let windowTitle = "문의하기"
    public static let placeholder = "버그나 바라는 기능을 적어 주세요"
    public static let notice = "앱 버전과 macOS 버전이 함께 전송돼요. 답장은 드리지 못해요."
    public static let sendButton = "보내기"
    public static let sending = "보내는 중…"
    public static let sent = "전달됐어요. 고마워요!"

    public static func characterCount(_ count: Int) -> String {
        "\(count)/\(FeedbackMessage.maximumTextLength)"
    }

    public static func failureMessage(for failure: FeedbackFailure) -> String {
        switch failure {
        case .rateLimited: "요청이 많아서 받지 못했어요. 잠시 뒤에 다시 보내 주세요."
        case .rejected: "전달하지 못했어요. 잠시 뒤에 다시 시도해 주세요."
        case .network: "인터넷에 연결되어 있는지 확인하고 다시 보내 주세요."
        }
    }
}
