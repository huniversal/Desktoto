import Domain
import Foundation
import Testing
@testable import SessionMonitoring

// MARK: - Claude

@Test func readsClaudeSessionDetails() async {
    let harness = Harness()
    let createdAt = harness.ago(3_600)
    harness.addClaudeLog(id: "claude-1", lines: [
        ClaudeLine.user(at: harness.ago(60), cwd: "/Users/test/projects/my-app", entrypoint: "cli"),
        ClaudeLine.assistant(at: harness.ago(50), stopReason: "tool_use", model: "claude-opus-4-7", usage: (input: 100, cacheCreation: 2_000, cacheRead: 30_000)),
        ClaudeLine.customTitle("로그 감시 구현", at: harness.ago(40)),
        ClaudeLine.lastPrompt("마지막 질문", at: harness.ago(40))
    ], createdAt: createdAt)
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "claude-1")

    #expect(info?.tool == .claude)
    #expect(info?.projectName == "my-app")
    #expect(info?.workingDirectory == "/Users/test/projects/my-app")
    #expect(info?.title == "로그 감시 구현")
    #expect(info?.modelName == "claude-opus-4-7")
    #expect(info?.usedTokens == 32_100)
    #expect(info?.windowTokens == 1_000_000)
    #expect(info?.isWindowEstimated == false)
    #expect(info?.isTerminalSession == true)
    #expect(info?.openURL == nil)
    #expect(info?.canOpen == true)
    #expect(info?.startedAt == createdAt)
    #expect(info?.isRunning == true)
}

@Test func claudeTitleFallsBackToLastPrompt() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.assistant(at: harness.ago(50)),
        ClaudeLine.lastPrompt("마지막 질문", at: harness.ago(40))
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()

    #expect(await monitor.sessionInfo(id: "s1")?.title == "마지막 질문")
}

@Test func claudeWithoutUsageOrFolderHasNoTokensAndUnknownProject() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [ClaudeLine.user(at: harness.ago(5))])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "s1")

    #expect(info?.usedTokens == nil)
    #expect(info?.windowTokens == nil)
    #expect(info?.modelName == nil)
    #expect(info?.title == nil)
    #expect(info?.projectName == "알 수 없음")
    #expect(info?.isTerminalSession == false)
    #expect(info?.canOpen == false)
}

@Test func claudeUsesTheLatestAssistantUsage() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.assistant(at: harness.ago(90), stopReason: "tool_use", model: "claude-opus-4-6", usage: (input: 1, cacheCreation: 1, cacheRead: 1)),
        ClaudeLine.assistant(at: harness.ago(60), stopReason: "tool_use", model: "claude-opus-4-7", usage: (input: 10, cacheCreation: 20, cacheRead: 30)),
        ClaudeLine.user(at: harness.ago(30), isToolResult: true)
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "s1")

    #expect(info?.modelName == "claude-opus-4-7")
    #expect(info?.usedTokens == 60)
}

@Test func claudeFindsUsageBeyondTheFirstInfoWindow() async {
    let harness = Harness()
    // 512KB 창에는 큰 줄의 뒷부분만 들어와 버려지므로, 4MB로 넓혀야 모델과 사용량이 보인다.
    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.assistant(at: harness.ago(60), stopReason: "tool_use", model: "claude-opus-4-7", usage: (input: 5, cacheCreation: 0, cacheRead: 0)),
        ClaudeLine.bigUser(at: harness.ago(30), padding: 600_000)
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "s1")

    #expect(info?.modelName == "claude-opus-4-7")
    #expect(info?.usedTokens == 5)
}

// MARK: - Codex

@Test func readsCodexDesktopSessionDetails() async {
    let harness = Harness()
    harness.addCodexLog(id: "codex-1", lines: [
        CodexLine.sessionMeta(at: harness.ago(300), originator: "Codex Desktop", id: "thread-1", cwd: "/Users/test/code/proj"),
        CodexLine.event("task_started", at: harness.ago(60)),
        CodexLine.turnContext(at: harness.ago(59), model: "gpt-5", cwd: "/Users/test/code/proj"),
        CodexLine.tokenCount(at: harness.ago(30), input: 12_345, window: 258_400),
        CodexLine.event("task_complete", at: harness.ago(10))
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "codex-1")

    #expect(info?.tool == .codex)
    #expect(info?.projectName == "proj")
    #expect(info?.modelName == "gpt-5")
    #expect(info?.usedTokens == 12_345)
    #expect(info?.windowTokens == 258_400)
    #expect(info?.isWindowEstimated == false)
    #expect(info?.openURL == URL(string: "codex://threads/thread-1"))
    #expect(info?.isTerminalSession == false)
    #expect(info?.title == nil)
    #expect(info?.isRunning == false)
}

@Test func codexTerminalOriginatorsAreTerminalSessionsWithoutOpenURL() async {
    let harness = Harness()
    for (id, originator) in [("tui", "codex-tui"), ("legacy", "codex_cli_rs"), ("other", "vscode")] {
        harness.addCodexLog(id: id, lines: [
            CodexLine.sessionMeta(at: harness.ago(300), originator: originator, id: "thread-\(id)", cwd: "/Users/test/p"),
            CodexLine.event("task_started", at: harness.ago(20))
        ])
    }
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()

    #expect(await monitor.sessionInfo(id: "tui")?.isTerminalSession == true)
    #expect(await monitor.sessionInfo(id: "legacy")?.isTerminalSession == true)
    #expect(await monitor.sessionInfo(id: "other")?.isTerminalSession == false)
    #expect(await monitor.sessionInfo(id: "tui")?.openURL == nil)
    #expect(await monitor.sessionInfo(id: "tui")?.canOpen == true)
}

@Test func codexFirstLineLargerThanLimitLeavesOriginUnknown() async {
    let harness = Harness()
    harness.addCodexLog(id: "huge-meta", lines: [
        CodexLine.sessionMeta(at: harness.ago(300), originator: "Codex Desktop", id: "thread-1", padding: 1_200_000),
        CodexLine.event("task_started", at: harness.ago(20))
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "huge-meta")

    #expect(info?.openURL == nil)
    #expect(info?.isTerminalSession == false)
}

@Test func codexOriginIsReadOnlyOncePerFile() async {
    let harness = Harness()
    let url = harness.addCodexLog(id: "codex-1", lines: [
        CodexLine.sessionMeta(at: harness.ago(300), originator: "Codex Desktop", id: "thread-1"),
        CodexLine.event("task_started", at: harness.ago(20))
    ])
    let monitor = harness.makeMonitor()
    _ = await monitor.sessionStates()
    _ = await monitor.sessionInfo(id: "codex-1")
    let readsAfterFirstInfo = harness.fileSystem.readCount(of: url)

    _ = await monitor.sessionInfo(id: "codex-1")

    // 두 번째 조회는 끝부분 읽기 1회만 늘고, 첫 줄(앞부분) 읽기는 캐시를 쓴다.
    #expect(harness.fileSystem.readCount(of: url) == readsAfterFirstInfo + 1)
}

@Test func sessionInfoIsNilForUnknownSession() async {
    let harness = Harness()
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()

    #expect(await monitor.sessionInfo(id: "nope") == nil)
}
