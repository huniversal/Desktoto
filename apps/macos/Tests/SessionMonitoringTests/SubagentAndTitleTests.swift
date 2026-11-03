import Domain
import Foundation
import Testing
@testable import SessionMonitoring

private func guardianSource() -> [String: Any] { ["subagent": ["other": "guardian"]] }
private func threadSpawnSource() -> [String: Any] { ["subagent": ["thread_spawn": ["parent_thread_id": "parent-thread"]]] }

private func codexLines(_ harness: Harness, id: String, source: Any?) -> [String] {
    [
        CodexLine.sessionMeta(at: harness.ago(60), originator: "Codex Desktop", id: id, cwd: "/Users/test/Desktoto", source: source),
        CodexLine.event("task_complete", at: harness.ago(30))
    ]
}

private func addTitleIndex(_ harness: Harness, lines: [String], modifiedAt: Date? = nil) {
    let url = harness.fileSystem.homeDirectory.appendingPathComponent(".codex/session_index.jsonl")
    harness.fileSystem.addFile(at: url, text: lines.joined(separator: "\n") + "\n", modifiedAt: modifiedAt ?? harness.ago(5))
}

private func indexLine(id: String, name: String) -> String {
    "{\"id\":\"\(id)\",\"thread_name\":\"\(name)\",\"updated_at\":\"2026-11-02T15:30:31.358989Z\"}"
}

// MARK: - 서브 에이전트 제외

@Test func excludesClaudeSubagentLogs() async {
    let harness = Harness()
    let line = ClaudeLine.assistant(at: harness.ago(30))
    harness.addClaudeLog(id: "main-session", lines: [line])
    let subagentURL = harness.fileSystem.homeDirectory
        .appendingPathComponent(".claude/projects/-Users-test-app/main-session/subagents/agent-a1b2c3.jsonl")
    harness.fileSystem.addFile(at: subagentURL, text: line + "\n", modifiedAt: harness.ago(1))

    let monitor = harness.makeMonitor()
    let states = await monitor.sessionStates()
    let sessions = await monitor.activeSessions()

    #expect(Set(states.keys) == ["main-session"])
    #expect(sessions.map(\.id) == ["main-session"])
}

@Test func keepsClaudeProjectWhoseNameContainsSubagentsWord() async {
    let harness = Harness()
    harness.addClaudeLog(id: "main-session", lines: [ClaudeLine.assistant(at: harness.ago(30))], project: "-Users-test-subagents")

    let states = await harness.makeMonitor().sessionStates()

    #expect(Set(states.keys) == ["main-session"])
}

@Test func excludesCodexGuardianAndSpawnedSubagentThreads() async {
    let harness = Harness()
    harness.addCodexLog(id: "chat", lines: codexLines(harness, id: "thread-chat", source: "vscode"))
    harness.addCodexLog(id: "guardian", lines: codexLines(harness, id: "thread-guardian", source: guardianSource()))
    harness.addCodexLog(id: "spawned", lines: codexLines(harness, id: "thread-spawned", source: threadSpawnSource()))

    let monitor = harness.makeMonitor()
    let states = await monitor.sessionStates()
    let sessions = await monitor.activeSessions()

    #expect(Set(states.keys) == ["chat"])
    #expect(sessions.map(\.id) == ["chat"])
}

@Test func keepsCodexLogsWithoutSourceOrWithTextSource() async {
    let harness = Harness()
    harness.addCodexLog(id: "no-source", lines: codexLines(harness, id: "thread-1", source: nil))
    harness.addCodexLog(id: "text-source", lines: codexLines(harness, id: "thread-2", source: "cli"))

    let states = await harness.makeMonitor().sessionStates()

    #expect(Set(states.keys) == ["no-source", "text-source"])
}

@Test func excludedSubagentsDoNotCreateWaitingSessions() async {
    let harness = Harness()
    harness.addCodexLog(id: "guardian", lines: codexLines(harness, id: "thread-guardian", source: guardianSource()))
    harness.addWaitingSignal(sessionID: "guardian", requestedAt: harness.ago(10))

    let monitor = harness.makeMonitor()
    _ = await monitor.sessionStates()
    let waiting = await monitor.waitingKinds()

    #expect(waiting.isEmpty)
}

// MARK: - Codex 제목

@Test func usesCodexThreadNameFromSessionIndex() async {
    let harness = Harness()
    harness.addCodexLog(id: "rollout-file-name", lines: codexLines(harness, id: "thread-1", source: "vscode"))
    addTitleIndex(harness, lines: [indexLine(id: "thread-1", name: "서브 에이전트 세션 표시 확인")])

    let sessions = await harness.makeMonitor().activeSessions()

    #expect(sessions.first?.title == "서브 에이전트 세션 표시 확인")
    #expect(sessions.first?.projectName == "Desktoto")
}

@Test func usesLatestThreadNameWhenThreadWasRenamed() async {
    let harness = Harness()
    harness.addCodexLog(id: "rollout", lines: codexLines(harness, id: "thread-1", source: "vscode"))
    addTitleIndex(harness, lines: [indexLine(id: "thread-1", name: "예전 이름"), indexLine(id: "thread-2", name: "다른 스레드"), indexLine(id: "thread-1", name: "바뀐 이름")])

    let sessions = await harness.makeMonitor().activeSessions()

    #expect(sessions.first?.title == "바뀐 이름")
}

@Test func codexTitleIsNilWhenIndexIsMissingOrHasNoEntry() async {
    let harness = Harness()
    harness.addCodexLog(id: "rollout", lines: codexLines(harness, id: "thread-1", source: "vscode"))
    let monitor = harness.makeMonitor()

    let withoutIndex = await monitor.activeSessions()
    addTitleIndex(harness, lines: [indexLine(id: "other-thread", name: "다른 스레드")])
    let withoutEntry = await monitor.activeSessions()

    #expect(withoutIndex.first?.title == nil)
    #expect(withoutEntry.first?.title == nil)
}

@Test func rereadsTitleIndexWhenFileChanges() async {
    let harness = Harness()
    harness.addCodexLog(id: "rollout", lines: codexLines(harness, id: "thread-1", source: "vscode"))
    addTitleIndex(harness, lines: [indexLine(id: "thread-1", name: "처음 이름")], modifiedAt: harness.ago(100))
    let monitor = harness.makeMonitor()
    let first = await monitor.activeSessions()

    addTitleIndex(harness, lines: [indexLine(id: "thread-1", name: "처음 이름"), indexLine(id: "thread-1", name: "새 이름")], modifiedAt: harness.ago(2))
    let second = await monitor.activeSessions()

    #expect(first.first?.title == "처음 이름")
    #expect(second.first?.title == "새 이름")
}

@Test func titleIndexSkipsBrokenLinesAndEmptyNames() {
    let data = Data([
        indexLine(id: "a", name: "가"),
        "깨진 줄",
        indexLine(id: "b", name: "   "),
        "{\"id\":\"c\"}",
        indexLine(id: "d", name: " 다 ")
    ].joined(separator: "\n").utf8)

    let titles = CodexTitleIndex.titles(from: data)

    #expect(titles == ["a": "가", "d": "다"])
}
