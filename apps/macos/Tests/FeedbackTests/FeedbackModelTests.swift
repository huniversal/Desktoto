import Foundation
import Testing
@testable import Feedback

// 열기 전에는 기다리게 하는 문. 보내는 도중의 상태를 검사할 때 쓴다.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

private struct FakeSender: FeedbackSending {
    let calls = CallLog<FeedbackMessage>()
    let behavior: @Sendable () async throws -> Void

    func send(_ message: FeedbackMessage) async throws {
        calls.append(message)
        try await behavior()
    }

    var callCount: Int { calls.count }
}

@MainActor
struct FeedbackModelTests {
    private func makeModel(text: String = "의견", sender: FakeSender) -> FeedbackModel {
        FeedbackModel(sender: sender, appVersion: "1.0.0", osVersion: "27.0.1", text: text)
    }

    private func waitUntilFinished(_ model: FeedbackModel) async {
        while model.phase == .sending { await Task.yield() }
    }

    // AC-4
    @Test(arguments: ["", "  ", "\n"])
    func cannotSendEmptyText(text: String) async {
        let sender = FakeSender(behavior: {})
        let model = makeModel(text: text, sender: sender)

        #expect(!model.canSend)
        await model.send()

        #expect(sender.callCount == 0)
        #expect(model.phase == .editing)
    }

    // AC-4
    @Test func limitsPastedText() {
        let model = makeModel(sender: FakeSender(behavior: {}))

        model.text = String(repeating: "가", count: FeedbackMessage.maximumTextLength + 100)

        #expect(model.text.unicodeScalars.count == FeedbackMessage.maximumTextLength)
    }

    // AC-4
    @Test func sendsTextWithVersionsAndFinishesAsSent() async {
        let sender = FakeSender(behavior: {})
        let model = makeModel(text: " 버그가 있어요 ", sender: sender)

        await model.send()

        #expect(model.phase == .sent)
        #expect(sender.calls.elements.first?.text == "버그가 있어요")
        #expect(sender.calls.elements.first?.appVersion == "1.0.0")
        #expect(sender.calls.elements.first?.osVersion == "27.0.1")
        #expect(!model.canSend)
    }

    // AC-4
    @Test func keepsTextAndAllowsRetryAfterFailure() async {
        let attempts = CallLog<Int>()
        let sender = FakeSender(behavior: {
            attempts.append(attempts.count + 1)
            if attempts.count == 1 { throw URLError(.notConnectedToInternet) }
        })
        let model = makeModel(text: "긴 의견", sender: sender)

        await model.send()
        #expect(model.phase == .failed(.network))
        #expect(model.text == "긴 의견")
        #expect(model.canSend)

        await model.send()
        #expect(model.phase == .sent)
        #expect(sender.callCount == 2)
    }

    // AC-4
    @Test(arguments: [
        (FeedbackSendFailure.rateLimited, FeedbackFailure.rateLimited),
        (FeedbackSendFailure.unexpectedStatus(404), FeedbackFailure.rejected),
        (FeedbackSendFailure.invalidResponse, FeedbackFailure.rejected)
    ])
    func mapsSendFailureToUserFacingFailure(failure: FeedbackSendFailure, expected: FeedbackFailure) async {
        let model = makeModel(sender: FakeSender(behavior: { throw failure }))

        await model.send()

        #expect(model.phase == .failed(expected))
    }

    // AC-4
    @Test func blocksDuplicateSendWhileSending() async {
        let gate = Gate()
        let sender = FakeSender(behavior: { await gate.wait() })
        let model = makeModel(sender: sender)

        model.startSending()
        #expect(model.phase == .sending)
        #expect(!model.canSend)
        model.startSending()

        await gate.open()
        await waitUntilFinished(model)

        #expect(model.phase == .sent)
        #expect(sender.callCount == 1)
    }

    // AC-4
    @Test func cancelDuringSendIgnoresLateResult() async {
        let gate = Gate()
        let sender = FakeSender(behavior: { await gate.wait() })
        let model = makeModel(sender: sender)

        model.startSending()
        model.cancelSending()
        #expect(model.phase == .editing)

        await gate.open()
        for _ in 0..<20 { await Task.yield() }

        #expect(model.phase == .editing)
    }
}
