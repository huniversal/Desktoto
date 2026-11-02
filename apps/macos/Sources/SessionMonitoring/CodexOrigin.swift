import Boundaries
import Foundation

/// Codex 기록 첫 줄(session_meta)의 originator, 작업 폴더, 스레드 id. 스레드 id는 파일 이름이 아니라 첫 줄의 id다.
struct CodexOrigin: Sendable, Equatable {
    let originator: String?
    let workingDirectory: String?
    let threadID: String?
    /// 서브 에이전트나 자동 리뷰(guardian)가 띄운 스레드인지. 일반 채팅은 source가 "vscode" 같은 문자열이고,
    /// 서브 에이전트는 source가 `{"subagent": ...}` 객체다.
    let isSubagent: Bool

    static let unknown = CodexOrigin(originator: nil, workingDirectory: nil, threadID: nil, isSubagent: false)

    var isDesktopSession: Bool {
        originator == SessionMonitoringPolicy.codexDesktopOriginator
    }

    var isTerminalSession: Bool {
        originator.map { SessionMonitoringPolicy.codexCLIOriginators.contains($0) } ?? false
    }

    var openURL: URL? {
        guard isDesktopSession, let threadID else { return nil }
        return URL(string: "codex://threads/\(threadID)")
    }
}

struct CodexOriginReader: Sendable {
    let fileSystem: any FileSystem

    /// 첫 줄은 지침이 들어 있어 수십 KB가 될 수 있으므로 줄바꿈이 나올 때까지(최대 1MB) 읽는다. 읽지 못하면 nil이다.
    func origin(of url: URL) -> CodexOrigin? {
        guard let head = fileSystem.readHead(of: url, maxBytes: SessionMonitoringPolicy.codexFirstLineMaxBytes),
              let lineEnd = head.firstIndex(of: 0x0A),
              let record = JSONValue.parseObject(from: Data(head.prefix(upTo: lineEnd))),
              let payload = record["payload"] else { return nil }
        return CodexOrigin(
            originator: payload["originator"]?.stringValue,
            workingDirectory: payload["cwd"]?.stringValue,
            threadID: payload["id"]?.stringValue,
            isSubagent: payload["source"]?.objectValue?["subagent"] != nil
        )
    }
}
