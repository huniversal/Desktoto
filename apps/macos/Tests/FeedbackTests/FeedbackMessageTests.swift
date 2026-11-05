import Foundation
import Testing
@testable import Feedback

struct FeedbackMessageTests {
    private func makeMessage(_ text: String) -> FeedbackMessage? {
        FeedbackMessage(text: text, appVersion: "1.2.3", osVersion: "27.0.1")
    }

    // AC-1
    @Test func trimsSurroundingWhitespace() {
        #expect(makeMessage("  \n버그예요\n  ")?.text == "버그예요")
    }

    // AC-1
    @Test(arguments: ["", "   ", "\n\t \n"])
    func rejectsEmptyText(text: String) {
        #expect(makeMessage(text) == nil)
    }

    // AC-1
    @Test func acceptsTextAtLimitAndRejectsOverLimit() {
        let limit = FeedbackMessage.maximumTextLength

        #expect(makeMessage(String(repeating: "가", count: limit)) != nil)
        #expect(makeMessage(String(repeating: "가", count: limit + 1)) == nil)
    }

    // AC-1
    @Test func limitedTextCutsAtLimitWithoutSplittingCharacters() {
        let limit = FeedbackMessage.maximumTextLength
        // 가족 이모지는 유니코드 스칼라 7개로 이루어진 글자 하나라서, 경계에서 반쪽으로 잘리면 안 된다.
        let family = "👨‍👩‍👧‍👦"
        let text = String(repeating: "a", count: limit - 3) + family

        let limited = FeedbackMessage.limitedText(text)

        #expect(limited == String(repeating: "a", count: limit - 3))
        #expect(limited.unicodeScalars.count <= limit)
        #expect(FeedbackMessage.limitedText("짧은 글") == "짧은 글")
    }

    // AC-1
    @Test func appendsVersionFooter() throws {
        let message = try #require(makeMessage("의견"))

        #expect(message.content == "의견\n\n-# Desktoto 1.2.3, macOS 27.0.1")
    }

    // AC-1
    @Test func requestBodyDisablesAllMentions() throws {
        let message = try #require(makeMessage("@everyone 안녕"))

        let body = try JSONSerialization.jsonObject(with: message.makeRequestBody()) as? [String: Any]
        let allowedMentions = body?["allowed_mentions"] as? [String: Any]

        #expect(body?["content"] as? String == message.content)
        #expect((allowedMentions?["parse"] as? [Any])?.isEmpty == true)
    }

    // AC-1
    @Test func contentStaysWithinDiscordLimitForWorstCaseInput() throws {
        let message = try #require(makeMessage(String(repeating: "가", count: FeedbackMessage.maximumTextLength)))

        #expect(message.content.unicodeScalars.count <= 2000)
    }

    @Test func formatsVersionTexts() {
        let version = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 1)

        #expect(FeedbackVersionText.osVersion(version) == "27.0.1")
        #expect(FeedbackVersionText.appVersion(from: ["CFBundleShortVersionString": "1.4.0"]) == "1.4.0")
        #expect(FeedbackVersionText.appVersion(from: nil) == "unknown")
        #expect(FeedbackVersionText.appVersion(from: ["CFBundleShortVersionString": ""]) == "unknown")
    }
}
