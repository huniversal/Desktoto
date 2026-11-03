import Boundaries
import Domain
import Foundation
import Testing
import TestSupport
@testable import SessionMonitoring

private var askQuestion: [(name: String, input: [String: Any])] { [(name: "AskUserQuestion", input: [:])] }
private var exitPlan: [(name: String, input: [String: Any])] { [(name: "ExitPlanMode", input: [:])] }

private func wrapUp(ask: String) -> [(name: String, input: [String: Any])] {
    [(name: "mcp__ccd_turn__wrap_up", input: ["recap": "요약", "ask": ask])]
}

// MARK: - hook 신호

@Test func validHookSignalMeansApprovalAndStopsRunning() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.user(at: harness.ago(60)),
        ClaudeLine.assistant(at: harness.ago(50), stopReason: "tool_use", tools: [(name: "Bash", input: [:])])
    ])
    harness.addWaitingSignal(sessionID: "s1", requestedAt: harness.ago(40))
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let kinds = await monitor.waitingKinds()
    let info = await monitor.sessionInfo(id: "s1")

    #expect(kinds == ["s1": .approval])
    #expect(info?.waitingKind == .approval)
    #expect(info?.isRunning == false)
    #expect(info?.isWaitingForUser == true)
}

@Test func hookSignalIsIgnoredOnceNewerConversationRecordExists() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.assistant(at: harness.ago(80), stopReason: "tool_use"),
        ClaudeLine.user(at: harness.ago(30), isToolResult: true)
    ])
    harness.addWaitingSignal(sessionID: "s1", requestedAt: harness.ago(40))
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let kinds = await monitor.waitingKinds()
    let info = await monitor.sessionInfo(id: "s1")

    #expect(kinds.isEmpty)
    #expect(info?.isRunning == true)
}

@Test func hookSignalExpiresAfterEighteenHundredSeconds() {
    let fileSystem = InMemoryFileSystem()
    let signalReader = WaitingSignalReader(fileSystem: fileSystem)
    let url = fileSystem.homeDirectory.appendingPathComponent(".ai-run/waiting/s1")

    fileSystem.addFile(at: url, text: "\(Int(referenceNow.timeIntervalSince1970) - 1_799)", modifiedAt: referenceNow)
    #expect(signalReader.isWaiting(sessionID: "s1", now: referenceNow, lastConversationAt: { nil }))

    fileSystem.addFile(at: url, text: "\(Int(referenceNow.timeIntervalSince1970) - 1_800)", modifiedAt: referenceNow)
    #expect(!signalReader.isWaiting(sessionID: "s1", now: referenceNow, lastConversationAt: { nil }))
}

@Test func hookSignalWithoutNumberFallsBackToFileModifiedTime() {
    let fileSystem = InMemoryFileSystem()
    let signalReader = WaitingSignalReader(fileSystem: fileSystem)
    let modifiedAt = referenceNow.addingTimeInterval(-90)
    fileSystem.addFile(at: fileSystem.homeDirectory.appendingPathComponent(".ai-run/waiting/s1"), text: "waiting", modifiedAt: modifiedAt)

    #expect(signalReader.requestedAt(sessionID: "s1") == modifiedAt)
    #expect(signalReader.requestedAt(sessionID: "other") == nil)
}

@Test func hookSignalSkipsReadingLogWhenMissingOrExpired() {
    let signalReader = WaitingSignalReader(fileSystem: InMemoryFileSystem())
    var didReadLog = false

    let isWaiting = signalReader.isWaiting(sessionID: "none", now: referenceNow, lastConversationAt: {
        didReadLog = true
        return nil
    })

    #expect(!isWaiting)
    #expect(!didReadLog)
}

// MARK: - 기록 기반 대기

@Test func askUserQuestionMeansQuestionAndExitPlanModeMeansApproval() async {
    let harness = Harness()
    harness.addClaudeLog(id: "ask", lines: [ClaudeLine.user(at: harness.ago(30)), ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use", tools: askQuestion)])
    harness.addClaudeLog(id: "plan", lines: [ClaudeLine.user(at: harness.ago(30)), ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use", tools: exitPlan)])
    harness.addClaudeLog(id: "bash", lines: [ClaudeLine.user(at: harness.ago(30)), ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use", tools: [(name: "Bash", input: [:])])])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let kinds = await monitor.waitingKinds()

    #expect(kinds == ["ask": .question, "plan": .approval])
}

@Test func endedTurnWithWrapUpQuestionMeansQuestion() async {
    let harness = Harness()
    harness.addClaudeLog(id: "asked", lines: [
        ClaudeLine.user(at: harness.ago(60)),
        ClaudeLine.assistant(at: harness.ago(50), stopReason: "tool_use", tools: wrapUp(ask: "계속할까요?")),
        ClaudeLine.user(at: harness.ago(49), isToolResult: true),
        ClaudeLine.assistant(at: harness.ago(40), stopReason: "end_turn")
    ])
    harness.addClaudeLog(id: "empty-ask", lines: [
        ClaudeLine.user(at: harness.ago(60)),
        ClaudeLine.assistant(at: harness.ago(50), stopReason: "tool_use", tools: wrapUp(ask: "")),
        ClaudeLine.user(at: harness.ago(49), isToolResult: true),
        ClaudeLine.assistant(at: harness.ago(40), stopReason: "end_turn")
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let kinds = await monitor.waitingKinds()

    #expect(kinds == ["asked": .question])
}

@Test func wrapUpQuestionFromPreviousTurnIsNotWaiting() async {
    let harness = Harness()
    harness.addClaudeLog(id: "answered", lines: [
        ClaudeLine.assistant(at: harness.ago(90), stopReason: "tool_use", tools: wrapUp(ask: "계속할까요?")),
        ClaudeLine.user(at: harness.ago(60), text: "네, 계속해 주세요"),
        ClaudeLine.assistant(at: harness.ago(40), stopReason: "end_turn")
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()

    #expect(await monitor.waitingKinds().isEmpty)
}

@Test func waitingClearsWhenUserAnswersAndFileChanges() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [ClaudeLine.assistant(at: harness.ago(30), stopReason: "tool_use", tools: askQuestion)], modifiedAt: harness.ago(30))
    let monitor = harness.makeMonitor()
    _ = await monitor.sessionStates()
    #expect(await monitor.waitingKinds() == ["s1": .question])

    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.assistant(at: harness.ago(30), stopReason: "tool_use", tools: askQuestion),
        ClaudeLine.user(at: harness.ago(2), isToolResult: true)
    ], modifiedAt: harness.ago(2))
    _ = await monitor.sessionStates()

    #expect(await monitor.waitingKinds().isEmpty)
}

@Test func codexSessionsAreNeverWaitingByLog() async {
    let harness = Harness()
    harness.addCodexLog(id: "c1", lines: [CodexLine.event("task_started", at: harness.ago(30))])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()

    #expect(await monitor.waitingKinds().isEmpty)
    #expect(await monitor.sessionInfo(id: "c1")?.isRunning == true)
}

@Test func waitingSessionIsNotRunningButOthersAre() async {
    let harness = Harness()
    harness.addClaudeLog(id: "waiting", lines: [ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use", tools: askQuestion)])
    harness.addClaudeLog(id: "busy", lines: [ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use", tools: [(name: "Bash", input: [:])])])
    let monitor = harness.makeMonitor()

    let sessions = await monitor.activeSessions()

    let byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    #expect(byID["waiting"]?.isRunning == false)
    #expect(byID["waiting"]?.waitingKind == .question)
    #expect(byID["busy"]?.isRunning == true)
    #expect(byID["busy"]?.waitingKind == nil)
}
