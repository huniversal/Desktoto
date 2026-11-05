import Testing
@testable import Feedback

struct FeedbackWebhookTests {
    // AC-2
    @Test func acceptsDiscordWebhookURL() {
        let webhook = FeedbackWebhook("https://discord.com/api/webhooks/123456/abc-DEF_ghi")

        #expect(webhook?.url.absoluteString == "https://discord.com/api/webhooks/123456/abc-DEF_ghi")
    }

    // AC-2
    @Test func trimsSurroundingWhitespace() {
        #expect(FeedbackWebhook("  https://discord.com/api/webhooks/1/x\n") != nil)
    }

    // AC-2
    @Test(arguments: [
        "",
        "   ",
        "not a url",
        "http://discord.com/api/webhooks/1/x",
        "https://example.com/api/webhooks/1/x",
        "https://discord.com.evil.example/api/webhooks/1/x",
        "https://discord.com@evil.example/api/webhooks/1/x",
        "https://user:pass@discord.com/api/webhooks/1/x",
        "https://discord.com:8443/api/webhooks/1/x",
        "https://discord.com/api/webhooks/",
        "https://discord.com/api/webhooks/1",
        "https://discord.com/api/webhooks/1/",
        "https://discord.com/api/webhooks/1/x/extra",
        "https://discord.com/api/webhooks/1/x?wait=true",
        "https://discord.com/api/webhooks/1/x#frag",
        "https://discord.com/other/1/x"
    ])
    func rejectsInvalidURL(text: String) {
        #expect(FeedbackWebhook(text) == nil)
    }

    // AC-2
    @Test func rejectsMissingValue() {
        #expect(FeedbackWebhook(nil as String?) == nil)
        #expect(FeedbackWebhook(infoDictionary: nil) == nil)
        #expect(FeedbackWebhook(infoDictionary: [:]) == nil)
        #expect(FeedbackWebhook(infoDictionary: ["FeedbackWebhookURL": 1]) == nil)
    }

    // AC-2
    @Test func readsFromInfoDictionary() {
        let info: [String: Any] = ["FeedbackWebhookURL": "https://discord.com/api/webhooks/1/x"]

        #expect(FeedbackWebhook(infoDictionary: info) != nil)
    }
}
