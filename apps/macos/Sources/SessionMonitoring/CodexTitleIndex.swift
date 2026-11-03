import Boundaries
import Foundation

/// Codex 데스크탑 앱이 스레드 제목을 적어 두는 `~/.codex/session_index.jsonl`의 해석.
/// 줄마다 `{"id", "thread_name", "updated_at"}`이고, 이름을 바꾸면 같은 id의 줄이 뒤에 덧붙으므로 마지막 줄이 현재 제목이다.
/// 기록 파일의 이름이 아니라 첫 줄의 스레드 id로 찾는다. 읽을 수 없는 줄과 빈 제목은 건너뛴다.
enum CodexTitleIndex {
    static func titles(from data: Data) -> [String: String] {
        var titles: [String: String] = [:]
        for line in data.split(separator: 0x0A) {
            guard let record = JSONValue.parseObject(from: Data(line)),
                  let id = record["id"]?.stringValue,
                  let name = record["thread_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            titles[id] = name
        }
        return titles
    }
}
