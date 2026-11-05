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
    case sending
    case sent
    case failed(FeedbackFailure)
}

// 입력 창의 상태. 입력 글과 전송 단계를 한 곳에서 소유하고, 보내는 동안 중복 전송을 막는다.
@MainActor
@Observable
public final class FeedbackModel {
    public var text: String {
        // 제한을 넘는 입력(붙여넣기 포함)은 잘라서 받는다.
        didSet {
            let limitedText = FeedbackMessage.limitedText(text)
            if limitedText != text { text = limitedText }
        }
    }
    public private(set) var phase: FeedbackPhase = .editing

    @ObservationIgnored private let sender: any FeedbackSending
    @ObservationIgnored private let appVersion: String
    @ObservationIgnored private let osVersion: String
    @ObservationIgnored private var sendTask: Task<Void, Never>?

    public init(sender: any FeedbackSending, appVersion: String, osVersion: String, text: String = "") {
        self.sender = sender
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.text = FeedbackMessage.limitedText(text)
    }

    public var canSend: Bool {
        guard phase != .sending, phase != .sent else { return false }
        return makeMessage() != nil
    }

    // 버튼에서 부르는 진입점. 전송 작업은 모델이 소유해서 창을 닫을 때 취소할 수 있다.
    // 단계는 Task가 시작되기 전에 바로 바꿔서, 연타해도 두 번째 전송이 시작되지 않는다.
    public func startSending() {
        guard let message = beginSending() else { return }
        sendTask = Task { await deliver(message) }
    }

    // 창을 닫을 때 진행 중인 전송을 취소한다. 보낸 뒤에는 아무 일도 하지 않는다.
    public func cancelSending() {
        sendTask?.cancel()
        sendTask = nil
        if phase == .sending { phase = .editing }
    }

    // 테스트에서 끝까지 기다리기 위해 분리했다. 보내는 중이거나 이미 보냈으면 다시 보내지 않는다.
    func send() async {
        guard let message = beginSending() else { return }
        await deliver(message)
    }

    private func beginSending() -> FeedbackMessage? {
        guard canSend, let message = makeMessage() else { return nil }
        phase = .sending
        return message
    }

    private func deliver(_ message: FeedbackMessage) async {
        do {
            try await sender.send(message)
            // 취소된 뒤에 도착한 결과가 상태를 바꾸지 않게 한다.
            guard !Task.isCancelled else { return }
            phase = .sent
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(Self.convertToFailure(error))
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
