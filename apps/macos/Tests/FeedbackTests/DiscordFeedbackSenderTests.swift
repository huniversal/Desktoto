import Foundation
import Testing
@testable import Feedback

struct DiscordFeedbackSenderTests {
    private static let webhookText = "https://discord.com/api/webhooks/1/token"

    private func makeMessage() throws -> FeedbackMessage {
        try #require(FeedbackMessage(text: "의견", appVersion: "1.0.0", osVersion: "27.0.1"))
    }

    private func makeSender(statusCode: Int, requests: CallLog<URLRequest> = CallLog()) throws -> DiscordFeedbackSender {
        let webhook = try #require(FeedbackWebhook(Self.webhookText))
        return DiscordFeedbackSender(webhook: webhook) { request in
            requests.append(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
    }

    // AC-3
    @Test(arguments: [200, 204])
    func treatsSuccessStatusAsSent(statusCode: Int) async throws {
        try await makeSender(statusCode: statusCode).send(makeMessage())
    }

    // AC-3
    @Test func reportsRateLimit() async throws {
        let sender = try makeSender(statusCode: 429)

        await #expect(throws: FeedbackSendFailure.rateLimited) {
            try await sender.send(makeMessage())
        }
    }

    // AC-3
    @Test(arguments: [400, 401, 404, 500, 503])
    func reportsOtherStatusAsFailure(statusCode: Int) async throws {
        let sender = try makeSender(statusCode: statusCode)

        await #expect(throws: FeedbackSendFailure.unexpectedStatus(statusCode)) {
            try await sender.send(makeMessage())
        }
    }

    // AC-3
    @Test func propagatesNetworkError() async throws {
        let webhook = try #require(FeedbackWebhook(Self.webhookText))
        let sender = DiscordFeedbackSender(webhook: webhook) { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: URLError.self) {
            try await sender.send(makeMessage())
        }
    }

    // AC-3: 데이터가 조금씩 들어와도 끝나지 않는 요청을 막도록 전체 제한(resource)도 10초로 둔다.
    @Test func defaultSessionEnforcesTotalDeadline() {
        let configuration = DiscordFeedbackSender.makeSession().configuration

        #expect(configuration.timeoutIntervalForResource == 10)
        #expect(configuration.timeoutIntervalForRequest == 10)
        // 디스크에 캐시를 남기지 않는 임시 세션이다.
        #expect(configuration.urlCache?.diskCapacity == 0)
    }

    // AC-3
    @Test func reportsNonHTTPResponseAsInvalid() async throws {
        let webhook = try #require(FeedbackWebhook(Self.webhookText))
        let sender = DiscordFeedbackSender(webhook: webhook) { request in
            (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        }

        await #expect(throws: FeedbackSendFailure.invalidResponse) {
            try await sender.send(makeMessage())
        }
    }

    // AC-1, AC-3
    @Test func postsJSONToWebhookWithTimeout() async throws {
        let requests = CallLog<URLRequest>()
        let message = try makeMessage()

        try await makeSender(statusCode: 204, requests: requests).send(message)

        let request = try #require(requests.elements.first)
        #expect(requests.count == 1)
        // 저장하지 못했을 때 성공 코드가 아니라 오류가 돌아오도록 `wait=true`를 붙인다.
        #expect(request.url?.absoluteString == "\(Self.webhookText)?wait=true")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.timeoutInterval == 10)
        #expect(request.httpBody == (try message.makeRequestBody()))
    }
}
