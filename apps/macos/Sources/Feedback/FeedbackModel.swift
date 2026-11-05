import Foundation
import Observation

public enum FeedbackFailure: Equatable, Sendable {
    // Discord가 요청이 너무 잦다고 거절했다.
    case rateLimited
    // 서버가 받지 않았다(삭제된 webhook, 서버 오류 등).
    case rejected
    // 네트워크 오류나 시간 초과로 닿지 못했다.
    case network
}

public enum FeedbackPhase: Equatable, Sendable {
    case editing
    // 직전 전송이 실패해서 글을 되돌려 놓은 상태. 오류를 보여 주고 다시 보낼 수 있다.
    case failed(FeedbackFailure)
}

// 입력 창의 상태. 보내기를 누르면 곧바로 보낸 것으로 보고(낙관적 업데이트) 호출한 쪽이 창을 닫는다.
// 전송은 모델이 끝까지 이어 가고, 실패했을 때만 결과로 알려서 글을 되돌릴 수 있게 한다.
@MainActor
@Observable
public final class FeedbackModel {
    // 한도를 넘는 글(붙여넣기, 실패한 글 되돌리기)도 자르지 않고 그대로 둔다. 사용자가 직접 줄이도록 `isOverLimit`으로 알리고 보내지 못하게 한다.
    public var text: String
    public private(set) var phase: FeedbackPhase = .editing

    @ObservationIgnored private let sender: any FeedbackSending
    @ObservationIgnored private let appVersion: String
    @ObservationIgnored private let osVersion: String
    @ObservationIgnored private var isDelivering = false

    public init(sender: any FeedbackSending, appVersion: String, osVersion: String, text: String = "") {
        self.sender = sender
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.text = text
    }

    public var textLength: Int {
        FeedbackMessage.textLength(of: text)
    }

    public var isOverLimit: Bool {
        textLength > FeedbackMessage.maximumTextLength
    }

    public var canSend: Bool {
        !isDelivering && makeMessage() != nil
    }

    // 보내기를 누르면 바로 불러서 창을 닫는다. 이미 보내는 중이거나 보낼 글이 없으면 아무 일도 하지 않는다.
    // `onResult`는 전송이 끝난 뒤 불린다. 성공이면 nil이고, 실패이면 이유를 준다.
    public func startSending(onResult: @escaping @MainActor (FeedbackFailure?) -> Void) {
        guard !isDelivering, let message = makeMessage() else { return }
        // 연타해도 두 번째 전송이 시작되지 않도록 Task보다 먼저 바꾼다.
        isDelivering = true
        phase = .editing
        Task {
            let failure = await deliver(message)
            isDelivering = false
            if let failure { phase = .failed(failure) }
            onResult(failure)
        }
    }

    // 전송에 실패한 글을 이미 열려 있는 창에 되돌린다. 새로 쓰던 글이 있으면 그 앞에 붙여서 어느 쪽도 잃지 않는다.
    // 합친 글이 한도를 넘으면 그대로 두고 `isOverLimit`으로 알린다.
    public func restore(failedText: String, failure: FeedbackFailure) {
        text = text.isEmpty ? failedText : "\(failedText)\n\n\(text)"
        phase = .failed(failure)
    }

    private func deliver(_ message: FeedbackMessage) async -> FeedbackFailure? {
        do {
            try await sender.send(message)
            return nil
        } catch {
            return Self.convertToFailure(error)
        }
    }

    private func makeMessage() -> FeedbackMessage? {
        FeedbackMessage(text: text, appVersion: appVersion, osVersion: osVersion)
    }

    private static func convertToFailure(_ error: Error) -> FeedbackFailure {
        guard let failure = error as? FeedbackSendFailure else { return .network }
        switch failure {
        case .rateLimited: return .rateLimited
        case .unexpectedStatus, .invalidResponse: return .rejected
        }
    }
}
