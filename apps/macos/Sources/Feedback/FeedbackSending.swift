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

// Discord webhook에 JSON을 한 번 POST한다. 응답 본문과 주소는 읽거나 남기지 않는다.
public struct DiscordFeedbackSender: FeedbackSending {
    public typealias Load = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    // 요청 하나가 끝나기까지 허용하는 전체 시간. 데이터가 조금씩 들어와도 이 시간이 지나면 실패로 본다.
    static let deadline: TimeInterval = 10

    // 기본 세션. `timeoutInterval`은 데이터가 올 때마다 늘어나는 유휴 제한이라서, 전체 제한(resource)을 따로 둔다.
    // 쿠키와 캐시를 남기지 않도록 ephemeral을 쓴다.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = deadline
        configuration.timeoutIntervalForResource = deadline
        return URLSession(configuration: configuration)
    }

    public static let defaultLoad: Load = { [session = makeSession()] request in
        try await session.data(for: request)
    }

    private let webhook: FeedbackWebhook
    private let load: Load

    public init(webhook: FeedbackWebhook, load: @escaping Load = DiscordFeedbackSender.defaultLoad) {
        self.webhook = webhook
        self.load = load
    }

    public func send(_ message: FeedbackMessage) async throws {
        var request = URLRequest(url: Self.makeRequestURL(for: webhook), timeoutInterval: Self.deadline)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Desktoto", forHTTPHeaderField: "User-Agent")
        request.httpBody = try message.makeRequestBody()
        let (_, response) = try await load(request)
        guard let httpResponse = response as? HTTPURLResponse else { throw FeedbackSendFailure.invalidResponse }
        try Self.judge(statusCode: httpResponse.statusCode)
    }

    // `wait=true`가 없으면 Discord가 메시지를 저장하지 못해도 성공 코드를 줄 수 있다. 저장 실패가 오류로 돌아오게 한다.
    static func makeRequestURL(for webhook: FeedbackWebhook) -> URL {
        guard var components = URLComponents(url: webhook.url, resolvingAgainstBaseURL: false) else { return webhook.url }
        components.queryItems = [URLQueryItem(name: "wait", value: "true")]
        return components.url ?? webhook.url
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
