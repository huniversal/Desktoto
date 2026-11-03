import Foundation

// Orca의 `terminal list`가 알려 주는 터미널 탭 하나.
struct OrcaTerminal: Equatable {
    let handle: String
    let worktreePath: String
    let title: String?
}

// Orca CLI 출력 해석과 탭 선택 로직 (순수 함수).
enum OrcaTerminalSelector {
    static func parseTerminals(_ data: Data) -> [OrcaTerminal] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let terminals = result["terminals"] as? [[String: Any]] else { return [] }
        return terminals.compactMap { terminal in
            guard let handle = terminal["handle"] as? String,
                  let worktreePath = terminal["worktreePath"] as? String else { return nil }
            return OrcaTerminal(handle: handle, worktreePath: worktreePath, title: terminal["title"] as? String)
        }
    }

    // 작업 폴더가 워크트리 폴더이거나 그 안쪽인 탭 중에서, 가장 깊은(가장 구체적인) 워크트리를 고른다.
    // 같은 워크트리에 탭이 여럿이면 탭 제목이 세션 제목과 겹치는 쪽을 우선한다.
    static func pickHandle(terminals: [OrcaTerminal], workingDirectory: String, sessionTitle: String?) -> String? {
        let target = normalizePath(workingDirectory)
        let matches = terminals.map { (terminal: $0, root: normalizePath($0.worktreePath)) }.filter {
            target == $0.root || target.hasPrefix("\($0.root)/")
        }
        guard let deepest = matches.map({ $0.root.count }).max() else { return nil }
        let candidates = matches.filter { $0.root.count == deepest }.map(\.terminal)
        if candidates.count > 1, let sessionTitle, !sessionTitle.isEmpty,
           let byTitle = candidates.first(where: { $0.title?.contains(sessionTitle) == true }) {
            return byTitle.handle
        }
        return candidates.first?.handle
    }

    static func hasSucceeded(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return json["ok"] as? Bool == true
    }

    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
