import Foundation
import Testing
@testable import SessionMonitoring

@Test func unchangedFileIsNotReadAgain() async {
    let harness = Harness()
    let url = harness.addClaudeLog(id: "s1", lines: [ClaudeLine.assistant(at: harness.ago(20))], modifiedAt: harness.ago(20))
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let readsAfterFirst = harness.fileSystem.readCount(of: url)
    harness.timeSource.advance(by: 5)
    _ = await monitor.sessionStates()
    _ = await monitor.sessionStates()

    #expect(readsAfterFirst == 1)
    #expect(harness.fileSystem.readCount(of: url) == readsAfterFirst)
}

@Test func changedModifiedTimeTriggersAnotherRead() async {
    let harness = Harness()
    let url = harness.addClaudeLog(id: "s1", lines: [ClaudeLine.assistant(at: harness.ago(20))], modifiedAt: harness.ago(20))
    let monitor = harness.makeMonitor()
    _ = await monitor.sessionStates()

    harness.fileSystem.setModifiedAt(harness.ago(2), at: url)
    _ = await monitor.sessionStates()

    #expect(harness.fileSystem.readCount(of: url) == 2)
}

@Test func cachedJudgementStillExpiresByTime() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [ClaudeLine.assistant(at: harness.ago(20))], modifiedAt: harness.ago(20))
    let monitor = harness.makeMonitor()
    #expect(await monitor.sessionStates().count == 1)

    harness.timeSource.advance(by: 700)

    #expect(await monitor.sessionStates().isEmpty)
}

@Test func removedFileDisappearsFromResults() async {
    let harness = Harness()
    harness.addClaudeLog(id: "s1", lines: [ClaudeLine.assistant(at: harness.ago(20))])
    harness.addClaudeLog(id: "s2", lines: [ClaudeLine.assistant(at: harness.ago(20))], project: "-Users-test-other")
    let monitor = harness.makeMonitor()
    #expect(await monitor.sessionStates().count == 2)

    harness.fileSystem.setModifiedAt(harness.ago(5_000), at: harness.claudeURL(id: "s2", project: "-Users-test-other"))

    #expect(Set(await monitor.sessionStates().keys) == ["s1"])
}

@Test func domainDerivedPropertiesFollowOpenURLAndWaitingKind() async {
    let harness = Harness()
    harness.addCodexLog(id: "c1", lines: [
        CodexLine.sessionMeta(at: harness.ago(100), originator: "Codex Desktop", id: "t1"),
        CodexLine.event("task_started", at: harness.ago(10))
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "c1")

    #expect(info?.canOpen == true)
    #expect(info?.isWaitingForUser == false)
}
