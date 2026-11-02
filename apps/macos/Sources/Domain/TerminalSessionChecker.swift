/// 터미널(CLI)에서 시작한 세션이 닫혔는지 묻는다. `SessionMonitoring`이 주입받고 `TerminalIntegration`이 구현한다.
public protocol TerminalSessionChecker: Sendable {
    /// 세션이 속한 터미널 프로세스가 끝났으면 true. 판단할 수 없으면 false다(목록에 남겨 둔다).
    /// Claude는 `sessionID`로, Codex는 같은 작업 폴더의 프로세스를 보므로 `workingDirectory`로 판단한다.
    func isClosed(sessionID: String, tool: AiTool, workingDirectory: String?) -> Bool
}
