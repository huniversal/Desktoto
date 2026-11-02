import Boundaries
import Foundation
import Synchronization
import TestSupport
import Testing
@testable import Preferences

private struct ScriptFailure: Error {}

private final class FakeNotificationCenter: NotificationCenterClient {
    struct Posted: Equatable {
        let title: String
        let body: String
        let userInfo: [String: String]
    }

    private let state = Mutex<(posted: [Posted], handler: (@Sendable (String) -> Void)?, activateCount: Int)>(([], nil, 0))

    var posted: [Posted] { state.withLock { $0.posted } }
    var activateCount: Int { state.withLock { $0.activateCount } }

    func activate(onOpenSession: @escaping @Sendable (String) -> Void) {
        state.withLock {
            $0.handler = onOpenSession
            $0.activateCount += 1
        }
    }

    func post(title: String, body: String, userInfo: [String: String]) {
        state.withLock { $0.posted.append(Posted(title: title, body: body, userInfo: userInfo)) }
    }

    func simulateClick(sessionID: String) {
        state.withLock { $0.handler }?(sessionID)
    }
}

struct NotificationSenderTests {
    // AC-6
    @Test func postsThroughNotificationCenterWithSessionIDInsideAppBundle() {
        let center = FakeNotificationCenter()
        let runner = RecordingAppleScriptRunner { _ in true }
        let sender = NotificationSender(isRunningAsApp: true, center: center, appleScriptRunner: runner)

        sender.send(title: "프로젝트", body: "작업이 끝났어요", sessionID: "s-1")

        #expect(center.posted == [.init(title: "프로젝트", body: "작업이 끝났어요", userInfo: ["sessionID": "s-1"])])
        #expect(runner.sources.isEmpty)
    }

    // AC-6
    @Test func fallsBackToAppleScriptOutsideAppBundle() {
        let center = FakeNotificationCenter()
        let runner = RecordingAppleScriptRunner { _ in true }
        let sender = NotificationSender(isRunningAsApp: false, center: center, appleScriptRunner: runner)

        sender.send(title: "프로젝트", body: "작업이 끝났어요", sessionID: "s-1")

        #expect(center.posted.isEmpty)
        #expect(runner.sources == [#"display notification "작업이 끝났어요" with title "프로젝트""#])
    }

    // AC-6
    @Test func escapesQuotesAndBackslashesInAppleScript() {
        let runner = RecordingAppleScriptRunner { _ in true }
        let sender = NotificationSender(isRunningAsApp: false, center: FakeNotificationCenter(), appleScriptRunner: runner)

        sender.send(title: #"a"b\c"#, body: #"x" & (do shell script "id") & ""#, sessionID: "s-1")

        #expect(runner.sources == [#"display notification "x\" & (do shell script \"id\") & \"" with title "a\"b\\c""#])
    }

    // AC-6
    @Test func ignoresAppleScriptFailure() {
        let runner = RecordingAppleScriptRunner { _ in throw ScriptFailure() }
        let sender = NotificationSender(isRunningAsApp: false, center: FakeNotificationCenter(), appleScriptRunner: runner)

        sender.send(title: "t", body: "b", sessionID: "s-1")

        #expect(runner.sources.count == 1)
    }

    // AC-6
    @Test func doesNotActivateCenterOutsideAppBundle() {
        let center = FakeNotificationCenter()
        let sender = NotificationSender(isRunningAsApp: false, center: center, appleScriptRunner: RecordingAppleScriptRunner { _ in true })

        sender.setUp { _ in }

        #expect(center.activateCount == 0)
    }

    // AC-7
    @MainActor
    @Test func deliversSessionIDOnMainActorWhenNotificationIsClicked() async {
        let center = FakeNotificationCenter()
        let sender = NotificationSender(isRunningAsApp: true, center: center, appleScriptRunner: RecordingAppleScriptRunner { _ in true })
        let (stream, continuation) = AsyncStream<String>.makeStream()
        sender.setUp { sessionID in continuation.yield(sessionID) }

        center.simulateClick(sessionID: "s-9")

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == "s-9")
        #expect(center.activateCount == 1)
    }

    // AC-7
    @Test func readsSessionIDFromUserInfo() {
        let userInfo = NotificationPayload.makeUserInfo(sessionID: "s-1")
        #expect(NotificationPayload.sessionID(from: userInfo) == "s-1")
        #expect(NotificationPayload.sessionID(from: [:]) == nil)
        #expect(NotificationPayload.sessionID(from: ["sessionID": 42]) == nil)
        #expect(NotificationPayload.sessionID(from: ["other": "s-1"]) == nil)
    }
}
