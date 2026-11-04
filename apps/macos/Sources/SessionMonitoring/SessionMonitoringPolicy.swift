import Foundation

/// 원본 `SessionWatcher`에 흩어져 있던 상수를 한곳에 모았다. 값은 원본과 같다.
enum SessionMonitoringPolicy {
    /// 수정 시각과 기록 안 마지막 활동이 모두 이 시간 안인 파일만 대상으로 삼는다.
    static let activeWindow: TimeInterval = 600
    /// 진행 중이던 Claude 세션을 이 시간까지 진행 중으로 본다. 대상 선정 창과 의미가 달라 따로 둔다.
    static let claudePendingWindow: TimeInterval = 600
    /// hook이 남긴 승인 대기 신호는 이 시간이 지나면 무시한다.
    static let waitingMaxAge: TimeInterval = 1800

    /// 기록 끝에는 도구 결과나 요청 원문처럼 수백 KB짜리 줄이 자주 붙는다. 작은 창으로 먼저 읽고, 찾지 못하면 범위를 넓힌다.
    static let stateTailByteSteps: [UInt64] = [65_536, 524_288, 4_194_304]
    static let infoTailByteSteps: [UInt64] = [524_288, 4_194_304, 16_777_216]

    /// Claude Code는 서브 에이전트의 기록을 `<프로젝트>/<세션>/subagents/agent-*.jsonl`에 따로 남긴다. 사용자가 보는 세션이 아니라서 제외한다.
    static let claudeSubagentDirectoryName = "subagents"

    /// Codex 데스크탑 앱이 스레드 제목을 적어 두는 파일. 홈 폴더 기준 경로다.
    static let codexTitleIndexPath = ".codex/session_index.jsonl"

    /// Antigravity App이 대화와 상태를 남기는 폴더. 홈 폴더 기준 경로다.
    static let antigravityRootPath = ".gemini/antigravity"

    /// Antigravity는 대화의 컨텍스트 창 크기를 파일에 남기지 않는다. Gemini 계열이 보통 100만 토큰대라서 이 값으로 추정하고 화면에 ~를 붙인다.
    static let antigravityEstimatedWindow = 1_048_576

    static let maxSessionCount = 10
    static let unknownProjectName = "알 수 없음"

    static let claudeDefaultWindow = 200_000
    static let claudeExtendedWindow = 1_000_000

    /// 진행 상태 판정은 대화 기록만, 세션 정보는 제목 줄까지 읽는다.
    static let claudeConversationTypes: Set<String> = ["user", "assistant"]
    static let claudeInfoTypes: Set<String> = ["user", "assistant", "custom-title", "last-prompt"]
    /// 활동으로 치는 Claude 기록. 제목, 마지막 프롬프트, 비용 같은 부가 기록은 세션을 다시 열 때 한꺼번에 덧붙여지므로 뺀다.
    static let claudeActivityTypes: Set<String> = ["user", "assistant", "api-request", "attachment", "system", "queue-operation"]
    /// Codex는 작업의 시작과 끝을 나타내는 기록으로 진행 여부를 판단한다. 그 뒤에 덧붙는 명령 완료 같은 기록은 무시한다.
    static let codexLifecycleTypes: Set<String> = ["task_started", "task_complete", "turn_aborted"]

    /// 데스크탑 앱은 originator가 "Codex Desktop"이다. 터미널의 codex CLI는 source가 "vscode"로 적혀 있어 구분에 쓸 수 없고,
    /// originator가 "codex-tui"(대화형) 또는 "codex_cli_rs"(예전 이름)다.
    static let codexDesktopOriginator = "Codex Desktop"
    static let codexCLIOriginators: Set<String> = ["codex-tui", "codex_cli_rs"]
    /// Codex 기록 첫 줄에는 지침이 들어 있어 수십 KB가 될 수 있다. 줄바꿈을 찾을 때까지 이 크기까지만 읽는다.
    static let codexFirstLineMaxBytes = 1_048_576
}
