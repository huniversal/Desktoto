import Boundaries
import Domain
import Foundation

/// 기록에서 세션의 모델, 사용 토큰, 제목, 작업 폴더를 읽어 `SessionInfo`로 만든다.
struct SessionInfoReader: Sendable {
    let windowResolver: ContextWindowResolver

    /// 진행 여부와 대기 이유는 호출하는 쪽이 판정해서 넘긴다. records는 최신순이다.
    func claudeInfo(
        records: [JSONValue],
        file: LogFile,
        startedAt: Date?,
        isRunning: Bool,
        waitingKind: WaitingKind?,
        openURL: URL?
    ) -> SessionInfo {
        let workingDirectory = records.compactMap { $0["cwd"]?.stringValue }.first
        let title = records.first { $0["type"]?.stringValue == "custom-title" }?["customTitle"]?.stringValue
            ?? records.first { $0["type"]?.stringValue == "last-prompt" }?["lastPrompt"]?.stringValue
        let latestMessage = records
            .first { $0["type"]?.stringValue == "assistant" && $0["message"]?["usage"] != nil }?["message"]

        let modelName = latestMessage?["model"]?.stringValue
        var usedTokens: Int?
        if let usage = latestMessage?["usage"]?.objectValue {
            let inputTokens = usage["input_tokens"]?.intValue ?? 0
            let cacheCreationTokens = usage["cache_creation_input_tokens"]?.intValue ?? 0
            let cacheReadTokens = usage["cache_read_input_tokens"]?.intValue ?? 0
            usedTokens = inputTokens + cacheCreationTokens + cacheReadTokens
        }
        let window = windowResolver.resolve(
            sessionID: file.id,
            modelName: modelName,
            usedTokens: usedTokens,
            workingDirectory: workingDirectory
        )

        return SessionInfo(
            id: file.id,
            tool: .claude,
            projectName: projectName(from: workingDirectory),
            title: title,
            modelName: modelName,
            usedTokens: usedTokens,
            windowTokens: usedTokens == nil ? nil : window.tokens,
            isWindowEstimated: window.isEstimated,
            isRunning: isRunning,
            waitingKind: waitingKind,
            openURL: openURL,
            workingDirectory: workingDirectory,
            startedAt: startedAt,
            isTerminalSession: records.contains { $0["entrypoint"]?.stringValue == "cli" }
        )
    }

    func codexInfo(
        records: [JSONValue],
        file: LogFile,
        origin: CodexOrigin,
        title: String? = nil,
        startedAt: Date?,
        isRunning: Bool,
        waitingKind: WaitingKind?
    ) -> SessionInfo {
        let payloads = records.compactMap { $0["payload"] }
        let workingDirectory = payloads.compactMap { $0["cwd"]?.stringValue }.first
        let modelName = payloads.compactMap { $0["model"]?.stringValue }.first
        let tokenInfo = payloads
            .first { $0["type"]?.stringValue == "token_count" && $0["info"]?.objectValue != nil }?["info"]

        return SessionInfo(
            id: file.id,
            tool: .codex,
            projectName: projectName(from: workingDirectory),
            title: title,
            modelName: modelName,
            usedTokens: tokenInfo?["last_token_usage"]?["input_tokens"]?.intValue,
            windowTokens: tokenInfo?["model_context_window"]?.intValue,
            isWindowEstimated: false,
            isRunning: isRunning,
            waitingKind: waitingKind,
            openURL: origin.openURL,
            workingDirectory: workingDirectory,
            startedAt: startedAt,
            isTerminalSession: origin.isTerminalSession
        )
    }

    private func projectName(from path: String?) -> String {
        guard let path, !path.isEmpty else { return SessionMonitoringPolicy.unknownProjectName }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}
