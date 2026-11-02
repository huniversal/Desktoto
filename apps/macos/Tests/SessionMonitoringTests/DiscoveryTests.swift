import Domain
import Foundation
import Testing
@testable import SessionMonitoring

@Test func findsClaudeAndCodexLogs() async {
    let harness = Harness()
    harness.addClaudeLog(id: "claude-1", lines: [ClaudeLine.assistant(at: harness.ago(30))])
    harness.addCodexLog(id: "codex-1", lines: [CodexLine.event("task_complete", at: harness.ago(30))])

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["claude-1": .completed, "codex-1": .completed])
}

@Test func ignoresHiddenFilesFoldersAndOtherExtensions() async {
    let harness = Harness()
    let line = ClaudeLine.assistant(at: harness.ago(30))
    harness.addClaudeLog(id: "visible", lines: [line])
    harness.addClaudeLog(id: "in-hidden-folder", lines: [line], project: ".hidden")
    harness.addClaudeLog(id: ".hidden-file", lines: [line])
    harness.fileSystem.addFile(at: harness.claudeURL(id: "notes").deletingPathExtension().appendingPathExtension("txt"), text: line, modifiedAt: harness.ago(1))

    let states = await harness.makeMonitor().sessionStates()

    #expect(Set(states.keys) == ["visible"])
}

@Test func usesStrictSixHundredSecondWindowOnModifiedTime() async {
    let harness = Harness()
    let line = ClaudeLine.assistant(at: harness.ago(10))
    harness.addClaudeLog(id: "at-599", lines: [line], modifiedAt: harness.ago(599))
    harness.addClaudeLog(id: "at-600", lines: [line], modifiedAt: harness.ago(600))

    let states = await harness.makeMonitor().sessionStates()

    #expect(Set(states.keys) == ["at-599"])
}

@Test func excludesLogsWhoseRecordsAreOldEvenIfModifiedJustNow() async {
    let harness = Harness()
    harness.addClaudeLog(id: "reopened-old", lines: [ClaudeLine.assistant(at: harness.ago(3_600))], modifiedAt: harness.ago(5))
    harness.addClaudeLog(id: "recent-edge", lines: [ClaudeLine.assistant(at: harness.ago(599))], modifiedAt: harness.ago(5))
    harness.addClaudeLog(id: "recent-over", lines: [ClaudeLine.assistant(at: harness.ago(600))], modifiedAt: harness.ago(5))
    harness.addCodexLog(id: "codex-old", lines: [CodexLine.event("task_complete", at: harness.ago(3_600))], modifiedAt: harness.ago(5))

    let states = await harness.makeMonitor().sessionStates()

    #expect(Set(states.keys) == ["recent-edge"])
}

@Test func auxiliaryRecordsDoNotCountAsActivity() async {
    let harness = Harness()
    // 제목 줄이 방금 덧붙었지만 실제 활동은 500초 전이다.
    harness.addClaudeLog(id: "retitled", lines: [
        ClaudeLine.assistant(at: harness.ago(500)),
        ClaudeLine.customTitle("새 제목", at: harness.ago(5)),
        ClaudeLine.lastPrompt("마지막", at: harness.ago(5))
    ], modifiedAt: harness.ago(5))
    harness.addClaudeLog(id: "working", lines: [ClaudeLine.user(at: harness.ago(100))], modifiedAt: harness.ago(100))

    let sessions = await harness.makeMonitor().activeSessions()

    #expect(sessions.map(\.id) == ["working", "retitled"])
}

@Test func returnsAtMostTenSessionsNewestFirst() async {
    let harness = Harness()
    for index in 1...12 {
        harness.addClaudeLog(id: "s\(index)", lines: [ClaudeLine.assistant(at: harness.ago(Double(index) * 10))])
    }

    let sessions = await harness.makeMonitor().activeSessions()

    #expect(sessions.map(\.id) == (1...10).map { "s\($0)" })
}

@Test func widensReadWindowWhenRecentLinesAreLargerThanFirstWindow() async {
    let harness = Harness()
    // 64KB 창에는 큰 줄의 뒷부분만 들어와 잘린 줄로 버려지므로, 512KB로 넓혀야 판정할 기록이 보인다.
    let url = harness.addClaudeLog(id: "big-tail", lines: [
        ClaudeLine.assistant(at: harness.ago(60)),
        ClaudeLine.attachment(at: harness.ago(5), padding: 100_000)
    ])

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["big-tail": .completed])
    #expect(harness.fileSystem.readCount(of: url) == 2)
}

@Test func fallsBackToModifiedTimeAndStoppedWhenNothingCanBeJudged() async {
    let harness = Harness()
    harness.addClaudeLog(id: "only-system", lines: [ClaudeLine.system(at: harness.ago(5))], modifiedAt: harness.ago(7))
    harness.addCodexLog(id: "no-lifecycle", lines: [CodexLine.tokenCount(at: harness.ago(5), input: 1, window: 2)], modifiedAt: harness.ago(7))

    let states = await harness.makeMonitor().sessionStates()

    #expect(states == ["only-system": .idle, "no-lifecycle": .idle])
}
