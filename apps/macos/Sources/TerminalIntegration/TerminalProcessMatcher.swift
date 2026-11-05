import Domain
import Foundation

/// 세션과 CLI 프로세스를 맞추는 순수 로직. 기록 파일에는 어느 프로세스의 세션인지 적혀 있지 않아서 작업 폴더와 시작 시각으로 맞춘다.
enum TerminalProcessMatcher {
    /// 프로세스는 세션 기록보다 먼저 시작된다. 기록 시작 직전(이 허용 오차 안)에 시작된 프로세스를 우선한다.
    static let startTimeMatchTolerance: TimeInterval = 120

    /// 도구별 CLI 프로세스 이름. 기록 파일의 도구와 같은 이름의 프로세스만 맞춘다.
    static func commandName(for tool: AiTool) -> String {
        switch tool {
        case .claude: "claude"
        case .codex: "codex"
        // 데스크탑 앱이라 터미널 프로세스와 맞추는 일이 없다. 모든 case를 다루기 위한 값이다.
        case .antigravity: "antigravity"
        }
    }

    static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// 작업 폴더가 같은 프로세스 중에서, 세션 시작 시각과 가장 가까이 시작된 것을 고른다.
    /// 후보가 하나뿐이거나 시작 시각을 모르면 첫 후보를 고른다. processes는 이름 필터를 거치지 않은 목록이어도 된다.
    static func match(processes: [TerminalProcess], tool: AiTool, workingDirectory: String, startedAt: Date?) -> TerminalProcess? {
        let target = normalizePath(workingDirectory)
        let name = commandName(for: tool)
        let candidates = processes.filter {
            guard $0.commandName == name, let directory = $0.workingDirectory else { return false }
            return normalizePath(directory) == target
        }
        guard candidates.count > 1, let startedAt else { return candidates.first }
        return candidates.min {
            abs($0.startedAt.timeIntervalSince(startedAt) + startTimeMatchTolerance / 2)
                < abs($1.startedAt.timeIntervalSince(startedAt) + startTimeMatchTolerance / 2)
        }
    }
}
