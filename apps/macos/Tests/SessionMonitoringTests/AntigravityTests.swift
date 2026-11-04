import Boundaries
import Domain
import Foundation
import TestSupport
import Testing
@testable import SessionMonitoring

/// 실제 SQLite 파일을 임시 홈 폴더에 만들어 Antigravity App의 상태 판정을 확인한다. 사용자의 실제 ~/.gemini는 읽지 않는다.
struct AntigravityTests {
    /// 승인 창이 떠 있을 때 마지막 단계에서 실제로 관찰한 값(Antigravity 2.29.0). 상수를 따라가지 않고 값을 직접 고정한다.
    private static let observedWaitingStatus = 9

    private final class Environment {
        let home: URL
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        private let summary: SQLiteFixture

        init() throws {
            home = FileManager.default.temporaryDirectory.appendingPathComponent("desktoto-agy-tests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: home.appendingPathComponent(".gemini/antigravity/conversations"), withIntermediateDirectories: true)
            summary = try #require(SQLiteFixture(url: home.appendingPathComponent(".gemini/antigravity/conversation_summaries.db")))
            #expect(summary.execute("""
            CREATE TABLE conversation_summaries (
              conversation_id text PRIMARY KEY, title text NOT NULL DEFAULT '', workspace_uris text NOT NULL DEFAULT '',
              status text NOT NULL DEFAULT '', killed integer NOT NULL DEFAULT 0, last_modified_time text NOT NULL,
              parent_conversation_id text NOT NULL DEFAULT '', nesting_depth integer NOT NULL DEFAULT 0)
            """))
        }

        deinit { try? FileManager.default.removeItem(at: home) }

        func makeMonitor() -> SessionMonitor {
            SessionMonitor(fileSystem: LiveFileSystem(homeDirectory: home), timeSource: FixedTimeSource(now: now))
        }

        private func timestamp(secondsAgo: TimeInterval) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS'+00:00'"
            return formatter.string(from: now.addingTimeInterval(-secondsAgo))
        }

        func addConversation(
            _ id: String, title: String = "", workspace: String = "file:///Users/test/projects/sample",
            status: String = "CASCADE_RUN_STATUS_IDLE", killed: Bool = false, secondsAgo: TimeInterval = 5,
            parent: String = "", depth: Int = 0
        ) {
            let workspaces = workspace.isEmpty ? "" : #"["\#(workspace)"]"#
            #expect(summary.execute("""
            INSERT OR REPLACE INTO conversation_summaries VALUES
            ('\(id)', '\(title)', '\(workspaces)', '\(status)', \(killed ? 1 : 0), '\(timestamp(secondsAgo: secondsAgo))', '\(parent)', \(depth))
            """))
        }

        /// 대화별 DB의 마지막 단계 상태를 정한다. 앞 단계는 모두 완료(3)로 둔다.
        func setLastStepStatus(_ id: String, _ status: Int) throws {
            let url = home.appendingPathComponent(".gemini/antigravity/conversations/\(id).db")
            let steps = try #require(SQLiteFixture(url: url))
            #expect(steps.execute("CREATE TABLE IF NOT EXISTS steps (idx integer PRIMARY KEY, step_type integer NOT NULL DEFAULT 0, status integer NOT NULL DEFAULT 0)"))
            #expect(steps.execute("INSERT OR REPLACE INTO steps VALUES (0, 14, 3), (1, 15, 3), (2, 132, \(status))"))
        }
    }

    @Test func runningConversationShowsAsRunningWithTitleAndProject() async throws {
        let environment = try Environment()
        environment.addConversation("running-id", title: "Korean Greeting", status: "CASCADE_RUN_STATUS_RUNNING")
        try environment.setLastStepStatus("running-id", 3)
        let monitor = environment.makeMonitor()
        #expect(await monitor.sessionStates() == ["running-id": .running])
        #expect(await monitor.waitingKinds().isEmpty)
        let session = try #require(await monitor.activeSessions().first)
        #expect(session.id == "running-id")
        #expect(session.tool == .antigravity)
        #expect(session.title == "Korean Greeting")
        #expect(session.projectName == "sample")
        #expect(session.workingDirectory == "/Users/test/projects/sample")
        #expect(session.isRunning)
        #expect(session.waitingKind == nil)
        #expect(session.isTerminalSession == false)
        #expect(await monitor.sessionInfo(id: "running-id") == session)
    }

    @Test func lastStepWaitingForApprovalShowsAsApprovalNotRunning() async throws {
        let environment = try Environment()
        environment.addConversation("waiting-id", status: "CASCADE_RUN_STATUS_RUNNING")
        try environment.setLastStepStatus("waiting-id", Self.observedWaitingStatus)
        let monitor = environment.makeMonitor()
        #expect(await monitor.sessionStates() == ["waiting-id": .running])
        #expect(await monitor.waitingKinds() == ["waiting-id": .approval])
        let session = try #require(await monitor.sessionInfo(id: "waiting-id"))
        #expect(session.waitingKind == .approval)
        #expect(session.isRunning == false)
    }

    @Test func approvalWaitStaysVisibleLongerThanPlainActivity() async throws {
        let environment = try Environment()
        let overWindow = SessionMonitoringPolicy.activeWindow + 60
        environment.addConversation("waiting-old", status: "CASCADE_RUN_STATUS_RUNNING", secondsAgo: overWindow)
        try environment.setLastStepStatus("waiting-old", Self.observedWaitingStatus)
        environment.addConversation("running-old", status: "CASCADE_RUN_STATUS_RUNNING", secondsAgo: overWindow)
        try environment.setLastStepStatus("running-old", 3)
        environment.addConversation("idle-old", status: "CASCADE_RUN_STATUS_IDLE", secondsAgo: overWindow)
        environment.addConversation("waiting-too-old", status: "CASCADE_RUN_STATUS_RUNNING", secondsAgo: SessionMonitoringPolicy.waitingMaxAge + 60)
        try environment.setLastStepStatus("waiting-too-old", Self.observedWaitingStatus)
        let monitor = environment.makeMonitor()
        #expect(await monitor.sessionStates() == ["waiting-old": .running])
        #expect(await monitor.waitingKinds() == ["waiting-old": .approval])
    }

    @Test func finishedConversationCompletesUnlessKilled() async throws {
        let environment = try Environment()
        environment.addConversation("done-id", status: "CASCADE_RUN_STATUS_IDLE")
        environment.addConversation("killed-id", status: "CASCADE_RUN_STATUS_IDLE", killed: true)
        let monitor = environment.makeMonitor()
        #expect(await monitor.sessionStates() == ["done-id": .completed, "killed-id": .idle])
        #expect(await monitor.waitingKinds().isEmpty)
    }

    @Test func subagentsAndStaleConversationsAreExcluded() async throws {
        let environment = try Environment()
        environment.addConversation("main-id", status: "CASCADE_RUN_STATUS_RUNNING")
        environment.addConversation("child-id", status: "CASCADE_RUN_STATUS_RUNNING", parent: "main-id")
        environment.addConversation("nested-id", status: "CASCADE_RUN_STATUS_RUNNING", depth: 1)
        environment.addConversation("stale-id", status: "CASCADE_RUN_STATUS_IDLE", secondsAgo: SessionMonitoringPolicy.activeWindow + 60)
        let monitor = environment.makeMonitor()
        #expect(Set(await monitor.sessionStates().keys) == ["main-id"])
        #expect(await monitor.activeSessions().map(\.id) == ["main-id"])
    }

    @Test func missingWorkspaceAndTitleFallBackToUnknownProject() async throws {
        let environment = try Environment()
        environment.addConversation("bare-id", workspace: "")
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.projectName == SessionMonitoringPolicy.unknownProjectName)
        #expect(session.title == nil)
        #expect(session.workingDirectory == nil)
    }

    @Test func absentOrUnexpectedDatabasesNeverCrashAndShowNothing() async throws {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("desktoto-agy-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        let absent = SessionMonitor(fileSystem: LiveFileSystem(homeDirectory: empty), timeSource: FixedTimeSource(now: Date()))
        #expect(await absent.sessionStates().isEmpty)
        #expect(await absent.activeSessions().isEmpty)

        let environment = try Environment()
        // 요약 테이블이 없는 다른 스키마
        let other = environment.home.appendingPathComponent(".gemini/antigravity/conversation_summaries.db")
        try FileManager.default.removeItem(at: other)
        try #require(SQLiteFixture(url: other)).execute("CREATE TABLE unrelated (x integer)")
        #expect(await environment.makeMonitor().sessionStates().isEmpty)
        // 데이터베이스가 아닌 파일
        try Data("not a database, just some text bytes".utf8).write(to: other)
        #expect(await environment.makeMonitor().activeSessions().isEmpty)
    }

    @Test func unknownStatusValuesAreTreatedAsNotRunningAndNotWaiting() async throws {
        let environment = try Environment()
        environment.addConversation("odd-id", status: "SOMETHING_NEW")
        environment.addConversation("odd-step-id", status: "CASCADE_RUN_STATUS_RUNNING")
        try environment.setLastStepStatus("odd-step-id", 42)
        let monitor = environment.makeMonitor()
        #expect(await monitor.sessionStates() == ["odd-id": .completed, "odd-step-id": .running])
        #expect(await monitor.waitingKinds().isEmpty)
    }

    @Test func changesInTheDatabasesAreReadAgain() async throws {
        let environment = try Environment()
        environment.addConversation("live-id", status: "CASCADE_RUN_STATUS_RUNNING")
        try environment.setLastStepStatus("live-id", 3)
        let monitor = environment.makeMonitor()
        #expect(await monitor.sessionStates() == ["live-id": .running])
        #expect(await monitor.waitingKinds().isEmpty)

        // 승인 대기로 바뀜(대화별 DB가 바뀜)
        try environment.setLastStepStatus("live-id", Self.observedWaitingStatus)
        try touch(environment.home.appendingPathComponent(".gemini/antigravity/conversations/live-id.db"), secondsFromNow: 10)
        _ = await monitor.sessionStates()
        #expect(await monitor.waitingKinds() == ["live-id": .approval])

        // 응답이 끝남(요약 DB가 바뀜)
        environment.addConversation("live-id", status: "CASCADE_RUN_STATUS_IDLE")
        try touch(environment.home.appendingPathComponent(".gemini/antigravity/conversation_summaries.db"), secondsFromNow: 20)
        #expect(await monitor.sessionStates() == ["live-id": .completed])
        #expect(await monitor.waitingKinds().isEmpty)
    }

    @Test func timestampsAndWorkspaceUrisParseTheObservedFormats() throws {
        let parsed = try #require(AntigravityReader.date(from: "2026-11-04 13:51:02.32072+00:00"))
        #expect(parsed == ISO8601DateFormatter().date(from: "2026-11-04T13:51:02Z"))
        #expect(AntigravityReader.date(from: "2026-11-04 13:51:02+00:00") != nil)
        #expect(AntigravityReader.date(from: "garbage") == nil)
        #expect(AntigravityReader.workspacePath(from: #"["file:///Users/a%20b/proj"]"#) == "/Users/a b/proj")
        #expect(AntigravityReader.workspacePath(from: "") == nil)
        #expect(AntigravityReader.workspacePath(from: "[]") == nil)
        #expect(AntigravityReader.workspacePath(from: #"["https://example.com"]"#) == nil)
        #expect(AntigravityReader.workspacePath(from: "not json") == nil)
    }

    /// 파일 수정 시각을 바꿔 캐시가 다시 읽게 한다. 같은 시각으로 두 번 읽히는 일을 피하기 위한 것이다.
    private func touch(_ url: URL, secondsFromNow: TimeInterval) throws {
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(secondsFromNow)], ofItemAtPath: url.path)
    }
}
