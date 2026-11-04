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

        /// 대화별 DB의 실행기 메타데이터(바이너리) 한 줄을 넣는다.
        func addExecutorMetadata(_ id: String, blob: Data, table: String = "executor_metadata") throws {
            let url = home.appendingPathComponent(".gemini/antigravity/conversations/\(id).db")
            let database = try #require(SQLiteFixture(url: url))
            #expect(database.execute("CREATE TABLE IF NOT EXISTS \(table) (idx integer PRIMARY KEY, data blob)"))
            let hex = blob.map { String(format: "%02x", $0) }.joined()
            #expect(database.execute("INSERT OR REPLACE INTO \(table) VALUES (0, x'\(hex)')"))
        }

        /// 대화 기록(JSONL)을 쓴다.
        func writeTranscript(_ id: String, lines: [String]) throws {
            let directory = home.appendingPathComponent(".gemini/antigravity/brain/\(id)/.system_generated/logs")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: directory.appendingPathComponent("transcript.jsonl"))
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

    /// 프로토콜 버퍼의 문자열 필드처럼 [태그, 길이, 값...]으로 만든다.
    private static func field(_ tag: UInt8, _ text: String) -> [UInt8] {
        [tag, UInt8(text.utf8.count)] + Array(text.utf8)
    }

    @Test func modelNameIsCutAtItsLengthByteEvenWhenTheNextTagLooksLikeALetter() {
        // 다음 필드의 태그 'j'(0x6a)가 이름 바로 뒤에 붙어 있어도 이름에 섞이지 않는다.
        var blob = Data([0x08, 0x01] + Self.field(0x0a, "gemini-3.8-flash-high"))
        blob.append(contentsOf: Self.field(0x6a, "enable-rpc-sandbox-proxy"))
        #expect(AntigravityReader.modelName(in: blob) == "gemini-3.8-flash-high")
        // 이름 앞에 다른 문자열이 있어도, 길이가 맞지 않는 gemini- 조각은 건너뛰고 맞는 것을 고른다.
        let mixed = Data(Self.field(0x12, "used_non_gemini_model") + Self.field(0x0a, "gemini-3.8-flash"))
        #expect(AntigravityReader.modelName(in: mixed) == "gemini-3.8-flash")
        #expect(AntigravityReader.modelName(in: Data()) == nil)
        #expect(AntigravityReader.modelName(in: Data("gemini-".utf8)) == nil)
        #expect(AntigravityReader.modelName(in: Data(Self.field(0x0a, "llama-3-70b"))) == nil)
        #expect(AntigravityReader.modelName(in: Data(Self.field(0x0a, "claude-sonnet-4-6") + Self.field(0x6a, "tail"))) == "claude-sonnet-4-6")
        #expect(AntigravityReader.modelName(in: Data(Self.field(0x0a, "gpt-oss-120b"))) == "gpt-oss-120b")
        // 길이가 실제보다 길면 읽지 않는다.
        #expect(AntigravityReader.modelName(in: Data([0x0a, 0x40] + Array("gemini-3.8-flash".utf8))) == nil)
    }

    @Test func sessionInfoCarriesModelAndEstimatedContextUsage() async throws {
        let environment = try Environment()
        environment.addConversation("rich-id", status: "CASCADE_RUN_STATUS_RUNNING")
        try environment.setLastStepStatus("rich-id", 3)
        try environment.addExecutorMetadata("rich-id", blob: Data(Self.field(0x0a, "gemini-3.8-flash-high") + Self.field(0x6a, "tail")))
        try environment.writeTranscript("rich-id", lines: [
            #"{"step_index":0,"type":"USER_INPUT","status":"DONE","content":"hi"}"#,
            #"{"step_index":1,"type":"PLANNER_RESPONSE","status":"DONE","input_tokens":1000,"cache_read_tokens":2000,"output_tokens":50}"#,
            #"{"step_index":2,"type":"GENERIC","status":"DONE","content":"tool result"}"#,
            #"{"step_index":3,"type":"PLANNER_RESPONSE","status":"DONE","input_tokens":3000,"cache_read_tokens":24000,"output_tokens":90}"#,
            #"{"step_index":4,"type":"GENERIC","status":"DONE","content":"later tool result"}"#
        ])
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.modelName == "gemini-3.8-flash-high")
        #expect(session.usedTokens == 27_000)
        #expect(session.windowTokens == 1_048_576)
        #expect(session.isWindowEstimated)
    }

    @Test(arguments: [("claude-sonnet-4-6", 200_000), ("gpt-oss-120b", 131_072), ("gemini-3.8-flash-high", 1_048_576)])
    func contextWindowIsEstimatedFromTheModelFamily(model: String, expectedWindow: Int) async throws {
        let environment = try Environment()
        environment.addConversation("model-id", status: "CASCADE_RUN_STATUS_IDLE")
        try environment.addExecutorMetadata("model-id", blob: Data(Self.field(0x0a, model)))
        try environment.writeTranscript("model-id", lines: [#"{"step_index":1,"type":"PLANNER_RESPONSE","input_tokens":1000,"cache_read_tokens":500}"#])
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.modelName == model)
        #expect(session.usedTokens == 1_500)
        #expect(session.windowTokens == expectedWindow)
        #expect(session.isWindowEstimated)
    }

    @Test func usageWithoutAKnownModelShowsNoPercentage() async throws {
        let environment = try Environment()
        environment.addConversation("unknown-id", status: "CASCADE_RUN_STATUS_IDLE")
        try environment.writeTranscript("unknown-id", lines: [#"{"step_index":1,"type":"PLANNER_RESPONSE","input_tokens":1000,"cache_read_tokens":500}"#])
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.modelName == nil)
        #expect(session.usedTokens == 1_500)
        #expect(session.windowTokens == nil)
        #expect(session.isWindowEstimated == false)
    }

    @Test func generationMetadataTextIsNotMistakenForAModelName() async throws {
        let environment = try Environment()
        environment.addConversation("gen-id", status: "CASCADE_RUN_STATUS_IDLE")
        // 생성 메타데이터에는 안내문 같은 텍스트가 들어 있고 `gemini-api` 같은 문자열이 모델 이름처럼 보일 수 있다.
        try environment.addExecutorMetadata("gen-id", blob: Data(Self.field(0x0a, "gemini-api")), table: "gen_metadata")
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.modelName == nil)
    }

    @Test func missingTranscriptAndMetadataLeaveModelAndUsageEmpty() async throws {
        let environment = try Environment()
        environment.addConversation("bare-id", status: "CASCADE_RUN_STATUS_IDLE")
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.modelName == nil)
        #expect(session.usedTokens == nil)
        #expect(session.windowTokens == nil)
        #expect(session.isWindowEstimated == false)
    }

    @Test func transcriptWithoutTokenFieldsOrWithBrokenLinesIsIgnored() async throws {
        let environment = try Environment()
        environment.addConversation("odd-id", status: "CASCADE_RUN_STATUS_IDLE")
        try environment.writeTranscript("odd-id", lines: [#"{"step_index":0,"type":"USER_INPUT"}"#, "{broken", #"{"input_tokens":"many"}"#])
        let session = try #require(await environment.makeMonitor().activeSessions().first)
        #expect(session.usedTokens == nil)
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
