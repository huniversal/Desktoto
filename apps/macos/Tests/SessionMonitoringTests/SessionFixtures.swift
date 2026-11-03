import Boundaries
import Domain
import Foundation
import TestSupport
@testable import SessionMonitoring

/// 모든 테스트가 쓰는 기준 시각. 실제 시계는 쓰지 않는다.
let referenceNow = Date(timeIntervalSince1970: 1_800_000_000)

private func makeLine(_ object: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
        preconditionFailure("합성 기록을 JSON으로 만들 수 없다")
    }
    return String(decoding: data, as: UTF8.self)
}

private func isoString(_ date: Date) -> String {
    date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
}

/// 합성 기록 한 줄을 판정 함수에 바로 넘길 수 있게 해석한다.
func parse(_ line: String) -> JSONValue? {
    JSONValue.parseObject(from: Data(line.utf8))
}

// MARK: - Claude 기록 한 줄

enum ClaudeLine {
    static func user(at date: Date, text: String? = "질문", isToolResult: Bool = false, cwd: String? = nil, entrypoint: String? = nil) -> String {
        var object: [String: Any] = ["type": "user", "timestamp": isoString(date)]
        if isToolResult {
            object["message"] = ["role": "user", "content": [["type": "tool_result", "content": "ok"]]]
        } else {
            object["message"] = ["role": "user", "content": text ?? ""]
        }
        if let cwd { object["cwd"] = cwd }
        if let entrypoint { object["entrypoint"] = entrypoint }
        return makeLine(object)
    }

    static func assistant(
        at date: Date,
        stopReason: String? = "end_turn",
        model: String? = nil,
        usage: (input: Int, cacheCreation: Int, cacheRead: Int)? = nil,
        tools: [(name: String, input: [String: Any])] = [],
        cwd: String? = nil
    ) -> String {
        var message: [String: Any] = ["role": "assistant"]
        message["content"] = tools.isEmpty
            ? [["type": "text", "text": "답변"]]
            : tools.map { ["type": "tool_use", "name": $0.name, "input": $0.input] as [String: Any] }
        if let stopReason { message["stop_reason"] = stopReason }
        if let model { message["model"] = model }
        if let usage {
            message["usage"] = [
                "input_tokens": usage.input,
                "cache_creation_input_tokens": usage.cacheCreation,
                "cache_read_input_tokens": usage.cacheRead
            ]
        }
        var object: [String: Any] = ["type": "assistant", "timestamp": isoString(date), "message": message]
        if let cwd { object["cwd"] = cwd }
        return makeLine(object)
    }

    static func customTitle(_ title: String, at date: Date) -> String {
        makeLine(["type": "custom-title", "customTitle": title, "timestamp": isoString(date)])
    }

    static func lastPrompt(_ prompt: String, at date: Date) -> String {
        makeLine(["type": "last-prompt", "lastPrompt": prompt, "timestamp": isoString(date)])
    }

    /// 활동으로 치지만 대화 기록은 아닌 줄. 길이를 키워 읽기 범위를 넘기는 데 쓴다.
    static func attachment(at date: Date, padding: Int = 0) -> String {
        makeLine(["type": "attachment", "timestamp": isoString(date), "padding": String(repeating: "x", count: padding)])
    }

    static func system(at date: Date) -> String {
        makeLine(["type": "system", "timestamp": isoString(date)])
    }

    /// 대화 기록이지만 크기만 키운 사용자 줄
    static func bigUser(at date: Date, padding: Int) -> String {
        user(at: date, text: String(repeating: "x", count: padding))
    }
}

// MARK: - Codex 기록 한 줄

enum CodexLine {
    static func sessionMeta(at date: Date, originator: String?, id: String?, cwd: String? = nil, padding: Int = 0, source: Any? = nil) -> String {
        var payload: [String: Any] = [:]
        if let source { payload["source"] = source }
        if let originator { payload["originator"] = originator }
        if let id { payload["id"] = id }
        if let cwd { payload["cwd"] = cwd }
        if padding > 0 { payload["instructions"] = String(repeating: "x", count: padding) }
        return makeLine(["type": "session_meta", "timestamp": isoString(date), "payload": payload])
    }

    static func event(_ type: String, at date: Date) -> String {
        makeLine(["type": "event_msg", "timestamp": isoString(date), "payload": ["type": type]])
    }

    static func turnContext(at date: Date, model: String?, cwd: String?) -> String {
        var payload: [String: Any] = ["type": "turn_context"]
        if let model { payload["model"] = model }
        if let cwd { payload["cwd"] = cwd }
        return makeLine(["type": "turn_context", "timestamp": isoString(date), "payload": payload])
    }

    static func tokenCount(at date: Date, input: Int, window: Int) -> String {
        makeLine([
            "type": "event_msg",
            "timestamp": isoString(date),
            "payload": [
                "type": "token_count",
                "info": ["last_token_usage": ["input_tokens": input], "model_context_window": window]
            ]
        ])
    }
}

// MARK: - 테스트 환경

struct Harness {
    let fileSystem = InMemoryFileSystem()
    let timeSource = FixedTimeSource(now: referenceNow)

    var now: Date { timeSource.now }

    func ago(_ seconds: TimeInterval) -> Date {
        now.addingTimeInterval(-seconds)
    }

    func makeMonitor(
        environment: [String: String] = [:],
        terminalSessionChecker: (any TerminalSessionChecker)? = nil,
        sessionLinkResolver: (any SessionLinkResolver)? = nil
    ) -> SessionMonitor {
        SessionMonitor(
            fileSystem: fileSystem,
            timeSource: timeSource,
            environment: environment,
            terminalSessionChecker: terminalSessionChecker,
            sessionLinkResolver: sessionLinkResolver
        )
    }

    func claudeURL(id: String, project: String = "-Users-test-app") -> URL {
        fileSystem.homeDirectory.appendingPathComponent(".claude/projects/\(project)/\(id).jsonl")
    }

    func codexURL(id: String) -> URL {
        fileSystem.homeDirectory.appendingPathComponent(".codex/sessions/2026/11/02/\(id).jsonl")
    }

    @discardableResult
    func addClaudeLog(
        id: String,
        lines: [String],
        modifiedAt: Date? = nil,
        createdAt: Date? = nil,
        project: String = "-Users-test-app"
    ) -> URL {
        let url = claudeURL(id: id, project: project)
        fileSystem.addFile(at: url, text: lines.map { "\($0)\n" }.joined(), modifiedAt: modifiedAt ?? ago(1), createdAt: createdAt)
        return url
    }

    @discardableResult
    func addCodexLog(id: String, lines: [String], modifiedAt: Date? = nil) -> URL {
        let url = codexURL(id: id)
        fileSystem.addFile(at: url, text: lines.map { "\($0)\n" }.joined(), modifiedAt: modifiedAt ?? ago(1))
        return url
    }

    /// hook이 남기는 승인 대기 신호 파일
    func addWaitingSignal(sessionID: String, content: String, modifiedAt: Date? = nil) {
        let url = fileSystem.homeDirectory.appendingPathComponent(".ai-run/waiting/\(sessionID)")
        fileSystem.addFile(at: url, text: content, modifiedAt: modifiedAt ?? now)
    }

    func addWaitingSignal(sessionID: String, requestedAt: Date) {
        addWaitingSignal(sessionID: sessionID, content: "\(Int(requestedAt.timeIntervalSince1970))")
    }
}
