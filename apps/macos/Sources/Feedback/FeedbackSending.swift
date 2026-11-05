import Foundation

public enum FeedbackSendFailure: Error, Equatable, Sendable {
    case rateLimited
    case unexpectedStatus(Int)
    case invalidResponse
}

// 의견을 밖으로 보내는 경계. 성공하면 반환하고, 보내지 못하면 던진다.
public protocol FeedbackSending: Sendable {
    func send(_ message: FeedbackMessage) async throws
}

// Discord webhook에 JSON을 한 번 POST한다. 성공하면 본문 없이 204가 온다. 응답 본문과 주소는 읽거나 남기지 않는다.
public struct DiscordFeedbackSender: FeedbackSending {
    public typealias Load = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let timeout: TimeInterval = 10

    private let webhook: FeedbackWebhook
    private let load: Load

    public init(webhook: FeedbackWebhook, load: @escaping Load = { try await URLSession.shared.data(for: $0) }) {
        self.webhook = webhook
        self.load = load
    }

    public func send(_ message: FeedbackMessage) async throws {
        var request = URLRequest(url: webhook.url, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Desktoto", forHTTPHeaderField: "User-Agent")
        request.httpBody = try message.makeRequestBody()
        let (_, response) = try await load(request)
        guard let httpResponse = response as? HTTPURLResponse else { throw FeedbackSendFailure.invalidResponse }
        try Self.judge(statusCode: httpResponse.statusCode)
    }

    // 상태 코드만 보고 판정하는 순수 함수. 2xx만 성공이다.
    static func judge(statusCode: Int) throws {
        switch statusCode {
        case 200..<300: return
        case 429: throw FeedbackSendFailure.rateLimited
        default: throw FeedbackSendFailure.unexpectedStatus(statusCode)
        }
    }
}
