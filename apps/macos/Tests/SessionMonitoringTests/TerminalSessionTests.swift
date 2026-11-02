import Domain
import Foundation
import Synchronization
import Testing
@testable import SessionMonitoring

/// 세션 id별로 닫힘 여부를 정해 두고, 받은 질문을 기록하는 가짜 TerminalSessionChecker.
private final class StubTerminalSessionChecker: TerminalSessionChecker {
    struct Query: Equatable {
        let sessionID: String
        let tool: AiTool
        let workingDirectory: String?
    }

    private let closedSessionIDs: Set<String>
    private let recordedQueries = Mutex<[Query]>([])

    init(closedSessionIDs: Set<String>) {
        self.closedSessionIDs = closedSessionIDs
    }

    var queries: [Query] {
        recordedQueries.withLock { $0 }
    }

    func isClosed(sessionID: String, tool: AiTool, workingDirectory: String?) -> Bool {
        recordedQueries.withLock { $0.append(Query(sessionID: sessionID, tool: tool, workingDirectory: workingDirectory)) }
        return closedSessionIDs.contains(sessionID)
    }
}

private struct StubSessionLinkResolver: SessionLinkResolver {
    let urls: [String: URL]

    func url(forSessionID sessionID: String) -> URL? {
        urls[sessionID]
    }
}

private func addTerminalSessions(to harness: Harness) {
    let line = ClaudeLine.user(at: harness.ago(30), cwd: "/Users/test/app", entrypoint: "cli")
    harness.addClaudeLog(id: "claude-open", lines: [line])
    harness.addClaudeLog(id: "claude-closed", lines: [line])
    harness.addClaudeLog(id: "claude-desktop", lines: [ClaudeLine.user(at: harness.ago(30), cwd: "/Users/test/app", entrypoint: "claude-desktop")])
    harness.addCodexLog(id: "codex-closed", lines: [
        CodexLine.sessionMeta(at: harness.ago(60), originator: "codex-tui", id: "thread-1", cwd: "/Users/test/code"),
        CodexLine.event("task_complete", at: harness.ago(30))
    ])
    harness.addCodexLog(id: "codex-desktop", lines: [
        CodexLine.sessionMeta(at: harness.ago(60), originator: "Codex Desktop", id: "thread-2", cwd: "/Users/test/code"),
        CodexLine.event("task_complete", at: harness.ago(30))
    ])
}

// AC-12
@Test func excludesClosedTerminalSessionsOnly() async {
    let harness = Harness()
    addTerminalSessions(to: harness)
    // 데스크탑 세션은 checker가 닫혔다고 답하더라도 터미널 세션이 아니므로 유지된다.
    let checker = StubTerminalSessionChecker(closedSessionIDs: ["claude-closed", "codex-closed", "claude-desktop", "codex-desktop"])
    let monitor = harness.makeMonitor(terminalSessionChecker: checker)

    let states = await monitor.sessionStates()
    let active = await monitor.activeSessions()

    #expect(Set(states.keys) == ["claude-open", "claude-desktop", "codex-desktop"])
    #expect(Set(active.map(\.id)) == ["claude-open", "claude-desktop", "codex-desktop"])
}

// AC-12
@Test func asksCheckerOnlyAboutTerminalSessions() async {
    let harness = Harness()
    addTerminalSessions(to: harness)
    let checker = StubTerminalSessionChecker(closedSessionIDs: [])

    _ = await harness.makeMonitor(terminalSessionChecker: checker).sessionStates()

    #expect(Set(checker.queries.map(\.sessionID)) == ["claude-open", "claude-closed", "codex-closed"])
    #expect(checker.queries.first { $0.sessionID == "codex-closed" } == .init(sessionID: "codex-closed", tool: .codex, workingDirectory: "/Users/test/code"))
    #expect(checker.queries.first { $0.sessionID == "claude-open" }?.tool == .claude)
}

// AC-12
@Test func behavesLikeBeforeWithoutChecker() async {
    let harness = Harness()
    addTerminalSessions(to: harness)

    let states = await harness.makeMonitor().sessionStates()

    #expect(states.count == 5)
}

// AC-12
@Test func readsClaudeTerminalOriginOnlyOnce() async {
    let harness = Harness()
    let url = harness.addClaudeLog(id: "claude-open", lines: [ClaudeLine.user(at: harness.ago(30), entrypoint: "cli")])
    let monitor = harness.makeMonitor(terminalSessionChecker: StubTerminalSessionChecker(closedSessionIDs: []))

    _ = await monitor.sessionStates()
    let readsAfterFirst = harness.fileSystem.readCount(of: url)
    _ = await monitor.sessionStates()

    #expect(harness.fileSystem.readCount(of: url) == readsAfterFirst)
}

// AC-13
@Test func fillsClaudeOpenURLFromResolver() async throws {
    let harness = Harness()
    harness.addClaudeLog(id: "mapped", lines: [ClaudeLine.user(at: harness.ago(30), entrypoint: "claude-desktop")])
    harness.addClaudeLog(id: "unmapped", lines: [ClaudeLine.user(at: harness.ago(30), entrypoint: "claude-desktop")])
    let url = try #require(URL(string: "claude://claude.ai/epitaxy/local_1"))
    let monitor = harness.makeMonitor(sessionLinkResolver: StubSessionLinkResolver(urls: ["mapped": url]))

    _ = await monitor.sessionStates()

    #expect(await monitor.sessionInfo(id: "mapped")?.openURL == url)
    #expect(await monitor.sessionInfo(id: "unmapped")?.openURL == nil)
}

// AC-13
@Test func leavesClaudeOpenURLNilWithoutResolver() async {
    let harness = Harness()
    harness.addClaudeLog(id: "mapped", lines: [ClaudeLine.user(at: harness.ago(30), entrypoint: "claude-desktop")])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()

    #expect(await monitor.sessionInfo(id: "mapped")?.openURL == nil)
}
