import Domain
import Foundation
import Testing
@testable import SessionMonitoring

// MARK: - Claude

@Test func claudeEndTurnAndStopSequenceMeanCompleted() async {
    let harness = Harness()
    harness.addClaudeLog(id: "end-turn", lines: [ClaudeLine.user(at: harness.ago(20)), ClaudeLine.assistant(at: harness.ago(10), stopReason: "end_turn")])
    harness.addClaudeLog(id: "stop-sequence", lines: [ClaudeLine.assistant(at: harness.ago(10), stopReason: "stop_sequence")])

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["end-turn": .completed, "stop-sequence": .completed])
}

@Test func claudeUnfinishedTurnsMeanRunning() async {
    let harness = Harness()
    harness.addClaudeLog(id: "tool-use", lines: [ClaudeLine.assistant(at: harness.ago(10), stopReason: "tool_use")])
    harness.addClaudeLog(id: "no-stop-reason", lines: [ClaudeLine.assistant(at: harness.ago(10), stopReason: nil)])
    harness.addClaudeLog(id: "user-last", lines: [ClaudeLine.assistant(at: harness.ago(20)), ClaudeLine.user(at: harness.ago(10))])
    harness.addClaudeLog(id: "tool-result-last", lines: [ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use"), ClaudeLine.user(at: harness.ago(10), isToolResult: true)])

    let states = await harness.makeMonitor().sessionStates()

    #expect(Set(states.values) == [.running])
    #expect(states.count == 4)
}

@Test func claudeNewActivityAfterCompletionMeansRunningAgain() async {
    let harness = Harness()
    harness.addClaudeLog(id: "second-turn", lines: [
        ClaudeLine.assistant(at: harness.ago(100), stopReason: "end_turn"),
        ClaudeLine.user(at: harness.ago(5))
    ])

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["second-turn": .running])
}

// MARK: - Codex

@Test func codexLifecycleDecidesState() async {
    let harness = Harness()
    harness.addCodexLog(id: "complete", lines: [CodexLine.event("task_started", at: harness.ago(30)), CodexLine.event("task_complete", at: harness.ago(10))])
    harness.addCodexLog(id: "aborted", lines: [CodexLine.event("task_started", at: harness.ago(30)), CodexLine.event("turn_aborted", at: harness.ago(10))])
    harness.addCodexLog(id: "started", lines: [CodexLine.event("task_started", at: harness.ago(30))])
    harness.addCodexLog(id: "restarted", lines: [CodexLine.event("task_complete", at: harness.ago(30)), CodexLine.event("task_started", at: harness.ago(10))])

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["complete": .completed, "aborted": .idle, "started": .running, "restarted": .running])
}

@Test func codexRecordsAfterCompletionAreIgnored() async {
    let harness = Harness()
    // 작업이 끝난 뒤에 덧붙는 명령 완료 같은 기록은 상태를 바꾸지 않는다.
    harness.addCodexLog(id: "late-event", lines: [
        CodexLine.event("task_started", at: harness.ago(100)),
        CodexLine.event("task_complete", at: harness.ago(60)),
        CodexLine.event("exec_command_end", at: harness.ago(5))
    ])

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["late-event": .completed])
}

// MARK: - 순수 판정

private func makeFile(tool: AiTool, outcome: LogOutcome, activity: Date) -> LogFile {
    LogFile(url: URL(fileURLWithPath: "/tmp/s.jsonl"), modifiedAt: activity, tool: tool, activity: activity, outcome: outcome)
}

@Test func inProgressExpiresAfterSixHundredSeconds() {
    for tool in AiTool.allCases {
        let activity = referenceNow.addingTimeInterval(-599)
        let expired = referenceNow.addingTimeInterval(-600)
        #expect(RunStateJudge.runState(for: makeFile(tool: tool, outcome: .inProgress, activity: activity), now: referenceNow) == .running)
        #expect(RunStateJudge.runState(for: makeFile(tool: tool, outcome: .inProgress, activity: expired), now: referenceNow) == .idle)
    }
}

@Test func completedAndStoppedIgnoreElapsedTime() {
    let old = referenceNow.addingTimeInterval(-10_000)
    #expect(RunStateJudge.runState(for: makeFile(tool: .claude, outcome: .completed, activity: old), now: referenceNow) == .completed)
    #expect(RunStateJudge.runState(for: makeFile(tool: .codex, outcome: .stopped, activity: referenceNow), now: referenceNow) == .idle)
}

@Test func activityJudgeUsesLatestRecordTimeNotModifiedTime() {
    let latest = referenceNow.addingTimeInterval(-30)
    let records = [
        parse(ClaudeLine.user(at: latest)),
        parse(ClaudeLine.assistant(at: latest.addingTimeInterval(-60), stopReason: "tool_use"))
    ].compactMap { $0 }

    let snapshot = ActivityJudge.snapshot(records: records, tool: .claude, modifiedAt: referenceNow)

    #expect(snapshot?.outcome == .inProgress)
    #expect(abs((snapshot?.lastActivity ?? .distantPast).timeIntervalSince(latest)) < 0.01)
}

@Test func codexActivityTimeComesFromTheLifecycleRecordWhenFinished() {
    let completedAt = referenceNow.addingTimeInterval(-100)
    let records = [
        parse(CodexLine.event("exec_command_end", at: referenceNow.addingTimeInterval(-5))),
        parse(CodexLine.event("task_complete", at: completedAt))
    ].compactMap { $0 }

    let snapshot = ActivityJudge.snapshot(records: records, tool: .codex, modifiedAt: referenceNow)

    #expect(snapshot?.outcome == .completed)
    #expect(abs((snapshot?.lastActivity ?? .distantPast).timeIntervalSince(completedAt)) < 0.01)
}

@Test func recordTimestampParsesWithAndWithoutFractionAndFallsBack() throws {
    let withFraction = try #require(parse(#"{"timestamp":"2026-11-02T03:04:05.678Z"}"#))
    let withoutFraction = try #require(parse(#"{"timestamp":"2026-11-02T03:04:05Z"}"#))
    let invalid = try #require(parse(#"{"timestamp":"yesterday"}"#))
    let missing = try #require(parse(#"{"type":"user"}"#))

    #expect(RecordTimestamp.date(of: withFraction) != nil)
    #expect(RecordTimestamp.date(of: withoutFraction)?.timeIntervalSince1970 == 1_793_588_645)
    #expect(RecordTimestamp.date(of: invalid) == nil)
    #expect(RecordTimestamp.date(of: missing, fallback: referenceNow) == referenceNow)
}
