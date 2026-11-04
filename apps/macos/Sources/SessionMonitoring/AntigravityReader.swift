import Boundaries
import Foundation

/// 요약 DB의 한 줄. Antigravity App의 대화 하나다.
struct AntigravityConversation: Sendable, Equatable {
    let id: String
    let title: String?
    let workspacePath: String?
    /// 요약 DB의 status가 RUNNING인지. 사람의 승인을 기다리는 중에도 true다.
    let isRunning: Bool
    let isKilled: Bool
    let lastModified: Date
}

/// Antigravity App(`~/.gemini/antigravity`)의 대화와 상태를 SQLite에서 읽는다.
/// 이 파일들은 문서화되지 않은 내부 형식이라, 없는 테이블이나 모르는 값은 오류 없이 "알 수 없음"으로 처리한다.
struct AntigravityReader: Sendable {
    /// 완료된 단계의 status. 승인을 기다리는 단계는 9였다(2026-11-04, Antigravity 2.29.0 실측).
    static let waitingStepStatus = 9
    private static let runningStatus = "CASCADE_RUN_STATUS_RUNNING"
    /// 최근 대화만 보면 되므로 오래된 대화까지 읽지 않는다.
    private static let recentConversationLimit = 30

    let fileSystem: any FileSystem
    let database: any SQLiteDatabase

    private var rootURL: URL { fileSystem.homeDirectory.appendingPathComponent(SessionMonitoringPolicy.antigravityRootPath) }
    var summaryDatabaseURL: URL { rootURL.appendingPathComponent("conversation_summaries.db") }

    func stepsDatabaseURL(conversationID: String) -> URL {
        rootURL.appendingPathComponent("conversations/\(conversationID).db")
    }

    /// 서브 에이전트(부모 대화가 있는 것)는 사용자가 따로 보는 대화가 아니라서 뺀다. 최신순이다.
    func recentConversations() -> [AntigravityConversation] {
        let sql = """
        SELECT conversation_id, title, workspace_uris, status, killed, last_modified_time \
        FROM conversation_summaries \
        WHERE parent_conversation_id = '' AND nesting_depth = 0 \
        ORDER BY last_modified_time DESC LIMIT \(Self.recentConversationLimit)
        """
        guard let rows = database.query(at: summaryDatabaseURL, sql: sql) else { return [] }
        return rows.compactMap(Self.conversation(from:))
    }

    func transcriptURL(conversationID: String) -> URL {
        rootURL.appendingPathComponent("brain/\(conversationID)/.system_generated/logs/transcript.jsonl")
    }

    /// 대화 기록에서 가장 최근 모델 응답의 컨텍스트 토큰(새 입력 + 캐시에서 읽은 입력)을 읽는다. 없으면 nil이다.
    func usedTokens(conversationID: String) -> Int? {
        let url = transcriptURL(conversationID: conversationID)
        for maxBytes in SessionMonitoringPolicy.stateTailByteSteps {
            let tail = LogTail.readRecords(of: url, maxBytes: maxBytes, fileSystem: fileSystem)
            if let record = tail.records.first(where: { $0["input_tokens"]?.intValue != nil }), let input = record["input_tokens"]?.intValue {
                return input + (record["cache_read_tokens"]?.intValue ?? 0)
            }
            if tail.isComplete { break }
        }
        return nil
    }

    /// 대화별 DB의 실행기 메타데이터(바이너리)에서 `gemini-3.8-flash-high`나 `claude-sonnet-4-6` 같은 모델 이름을 찾는다. 못 찾으면 nil이다.
    /// 생성 메타데이터(`gen_metadata`)에는 안내문 같은 긴 텍스트가 섞여 있어 `gemini-api` 같은 문자열을 모델로 잘못 읽을 수 있어서 보지 않는다.
    func modelName(conversationID: String) -> String? {
        let rows = database.query(at: stepsDatabaseURL(conversationID: conversationID), sql: "SELECT data FROM executor_metadata ORDER BY idx DESC LIMIT 3") ?? []
        for case .blob(let blob)? in rows.map({ $0["data"] }) {
            if let name = Self.modelName(in: blob) { return name }
        }
        return nil
    }

    /// Antigravity가 지원하는 모델 계열의 이름 접두어(Gemini, Claude, GPT-OSS).
    private static let modelNamePrefixes = ["gemini-", "claude-", "gpt-"].map { Array($0.utf8) }

    /// 프로토콜 버퍼의 문자열 필드는 값 바로 앞 바이트가 길이다. 모델 이름 접두어로 시작하는 문자열을 찾아 그 길이만큼만 잘라서,
    /// 뒤따르는 다음 필드의 태그 바이트가 글자로 보여 이름에 섞이는 일을 막는다. 형식이 맞지 않으면 건너뛴다.
    static func modelName(in data: Data) -> String? {
        let bytes = [UInt8](data)
        for prefix in modelNamePrefixes where bytes.count > prefix.count {
            for start in 1...(bytes.count - prefix.count) where Array(bytes[start..<(start + prefix.count)]) == prefix {
                let length = Int(bytes[start - 1])
                guard length > prefix.count, start + length <= bytes.count,
                      let text = String(bytes: bytes[start..<(start + length)], encoding: .ascii),
                      text.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "." || $0 == "-" }) else { continue }
                return text
            }
        }
        return nil
    }

    /// 가장 마지막 단계가 승인 대기 상태인지. 읽지 못하면 false다.
    func isWaitingForApproval(conversationID: String) -> Bool {
        let sql = "SELECT status FROM steps ORDER BY idx DESC LIMIT 1"
        guard let status = database.query(at: stepsDatabaseURL(conversationID: conversationID), sql: sql)?.first?["status"]?.intValue else { return false }
        return status == Self.waitingStepStatus
    }

    static func conversation(from row: SQLiteRow) -> AntigravityConversation? {
        guard let id = row["conversation_id"]?.stringValue, !id.isEmpty,
              let lastModified = row["last_modified_time"]?.stringValue.flatMap(date(from:)) else { return nil }
        let title = row["title"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        return AntigravityConversation(
            id: id,
            title: title,
            workspacePath: row["workspace_uris"]?.stringValue.flatMap(workspacePath(from:)),
            isRunning: row["status"]?.stringValue == runningStatus,
            isKilled: (row["killed"]?.intValue ?? 0) != 0,
            lastModified: lastModified
        )
    }

    /// `2026-11-04 13:51:02.32072+00:00`처럼 소수 자리 수가 일정하지 않고 T 대신 공백이 들어간 시각이다.
    static func date(from text: String) -> Date? {
        let isoText = text.replacingOccurrences(of: " ", with: "T", options: [], range: text.range(of: " "))
            .replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: isoText)
    }

    /// `["file:///Users/me/project"]` 같은 JSON 배열에서 첫 작업 폴더의 경로를 꺼낸다. 비어 있거나 모르는 형식이면 nil이다.
    static func workspacePath(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let uris = try? JSONSerialization.jsonObject(with: data) as? [String],
              let first = uris.first, let url = URL(string: first), url.isFileURL else { return nil }
        return url.path
    }
}
