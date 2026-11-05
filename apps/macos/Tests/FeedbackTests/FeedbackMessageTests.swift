import Foundation
import Testing
@testable import Feedback

struct FeedbackMessageTests {
    private func makeMessage(_ text: String, appVersion: String = "1.2.3") -> FeedbackMessage? {
        FeedbackMessage(text: text, appVersion: appVersion, osVersion: "27.0.1")
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

    // AC-1: 글자 수는 UTF-16 코드 단위로 센다. 이모지는 코드 단위가 둘이라 절반만 들어간다.
    @Test func countsNonBMPCharactersAsTwoUnits() {
        let limit = FeedbackMessage.maximumTextLength

        #expect(makeMessage(String(repeating: "😀", count: limit / 2)) != nil)
        #expect(makeMessage(String(repeating: "😀", count: limit / 2 + 1)) == nil)
        #expect(FeedbackMessage.textLength(of: "😀") == 2)
    }

    // AC-1: 입력 창의 글자 수는 보낼 때 다듬는 것과 같은 기준이다.
    @Test func textLengthIgnoresSurroundingWhitespace() {
        #expect(FeedbackMessage.textLength(of: "  가나다 \n") == 3)
        #expect(FeedbackMessage.textLength(of: "   ") == 0)
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

    // AC-1: 가장 긴 입력(한도까지 찬 이모지 글)도 푸터를 붙인 전체가 Discord 한도 안에 든다.
    @Test(arguments: ["가", "😀"])
    func contentStaysWithinDiscordLimitForWorstCaseInput(character: String) throws {
        let unitsPerCharacter = character.utf16.count
        let text = String(repeating: character, count: FeedbackMessage.maximumTextLength / unitsPerCharacter)
        let message = try #require(makeMessage(text))

        #expect(message.content.utf16.count <= FeedbackMessage.maximumContentLength)
    }

    // AC-1: 버전 문자열이 비정상적으로 길어서 전체가 한도를 넘으면 만들지 않는다.
    @Test func rejectsWhenVersionFooterPushesContentOverLimit() {
        let longVersion = String(repeating: "9", count: 600)

        #expect(makeMessage(String(repeating: "가", count: FeedbackMessage.maximumTextLength), appVersion: longVersion) == nil)
        #expect(makeMessage("짧은 글", appVersion: longVersion) != nil)
    }

    @Test func formatsVersionTexts() {
        let version = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 1)

        #expect(FeedbackVersionText.osVersion(version) == "27.0.1")
        #expect(FeedbackVersionText.appVersion(from: ["CFBundleShortVersionString": "1.4.0"]) == "1.4.0")
        #expect(FeedbackVersionText.appVersion(from: nil) == "unknown")
        #expect(FeedbackVersionText.appVersion(from: ["CFBundleShortVersionString": ""]) == "unknown")
    }
}
