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

    // 전송이 끝날 때까지 기다렸다가 결과(성공이면 nil)를 돌려준다.
    private func sendAndWait(_ model: FeedbackModel) async -> FeedbackFailure? {
        await withCheckedContinuation { continuation in
            model.startSending { continuation.resume(returning: $0) }
        }
    }

    // AC-4
    @Test(arguments: ["", "  ", "\n"])
    func cannotSendEmptyText(text: String) {
        let sender = FakeSender(behavior: {})
        let model = makeModel(text: text, sender: sender)

        #expect(!model.canSend)
        model.startSending { _ in Issue.record("빈 글은 전송을 시작하면 안 된다") }

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
    @Test func sendsTrimmedTextWithVersionsAndReportsSuccess() async {
        let sender = FakeSender(behavior: {})
        let model = makeModel(text: " 버그가 있어요 ", sender: sender)

        let failure = await sendAndWait(model)

        #expect(failure == nil)
        #expect(model.phase == .editing)
        #expect(sender.calls.elements.first?.text == "버그가 있어요")
        #expect(sender.calls.elements.first?.appVersion == "1.0.0")
        #expect(sender.calls.elements.first?.osVersion == "27.0.1")
    }

    // AC-4
    @Test func keepsTextAndAllowsRetryAfterFailure() async {
        let attempts = CallLog<Int>()
        let sender = FakeSender(behavior: {
            attempts.append(attempts.count + 1)
            if attempts.count == 1 { throw URLError(.notConnectedToInternet) }
        })
        let model = makeModel(text: "긴 의견", sender: sender)

        let firstFailure = await sendAndWait(model)
        #expect(firstFailure == .network)
        #expect(model.phase == .failed(.network))
        #expect(model.text == "긴 의견")
        #expect(model.canSend)

        let secondFailure = await sendAndWait(model)
        #expect(secondFailure == nil)
        #expect(model.phase == .editing)
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

        let result = await sendAndWait(model)

        #expect(result == expected)
        #expect(model.phase == .failed(expected))
    }

    // AC-4
    @Test func blocksDuplicateSendWhileDelivering() async {
        let gate = Gate()
        let sender = FakeSender(behavior: { await gate.wait() })
        let model = makeModel(sender: sender)

        let failure: FeedbackFailure? = await withCheckedContinuation { continuation in
            model.startSending { continuation.resume(returning: $0) }
            // 전송이 끝나기 전에 바로 막혀야 한다.
            #expect(!model.canSend)
            model.startSending { _ in Issue.record("전송 중에 두 번째 전송이 시작되면 안 된다") }
            Task { await gate.open() }
        }

        #expect(failure == nil)
        #expect(sender.callCount == 1)
    }

    // AC-4
    @Test func clearsPreviousFailureWhenSendingAgain() async {
        let attempts = CallLog<Int>()
        let sender = FakeSender(behavior: {
            attempts.append(attempts.count + 1)
            if attempts.count == 1 { throw FeedbackSendFailure.unexpectedStatus(500) }
        })
        let model = makeModel(sender: sender)
        _ = await sendAndWait(model)
        #expect(model.phase == .failed(.rejected))

        model.startSending { _ in }

        #expect(model.phase == .editing)
    }

    // AC-4
    @Test func restoresFailedTextInFrontOfNewText() {
        let model = makeModel(text: "", sender: FakeSender(behavior: {}))

        model.restore(failedText: "실패한 글", failure: .network)
        #expect(model.text == "실패한 글")
        #expect(model.phase == .failed(.network))

        model.text = "실패한 글\n\n새 글"
        model.restore(failedText: "또 실패한 글", failure: .rejected)
        #expect(model.text == "또 실패한 글\n\n실패한 글\n\n새 글")
        #expect(model.phase == .failed(.rejected))
    }
}
