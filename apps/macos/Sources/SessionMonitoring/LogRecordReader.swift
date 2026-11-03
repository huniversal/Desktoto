import Boundaries
import Domain
import Foundation

/// 기록 파일 끝부분을 단계적으로 넓혀 가며 읽는다.
struct LogRecordReader: Sendable {
    let fileSystem: any FileSystem

    /// steps의 크기 순서대로 끝부분을 읽다가 isSufficient가 참이거나 파일 처음까지 읽으면 멈추고, 그때의 기록(최신순)을 돌려준다.
    /// 끝까지 충분하지 않으면 마지막 단계에서 읽은 기록을 돌려준다.
    /// Claude는 claudeTypes에 해당하는 줄만, Codex는 모든 줄을 쓴다.
    func records(
        at url: URL,
        tool: AiTool,
        claudeTypes: Set<String>,
        steps: [UInt64],
        isSufficient: ([JSONValue]) -> Bool
    ) -> [JSONValue] {
        var records: [JSONValue] = []
        for maxBytes in steps {
            let tail = LogTail.readRecords(of: url, maxBytes: maxBytes, fileSystem: fileSystem)
            records = tool == .codex
                ? tail.records
                : tail.records.filter { claudeTypes.contains($0["type"]?.stringValue ?? "") }
            if isSufficient(records) || tail.isComplete { break }
        }
        return records
    }

    /// 마지막 대화 기록을 찾을 때까지 읽는 범위를 단계적으로 넓힌다.
    func lastConversationRecord(of file: LogFile) -> JSONValue? {
        records(
            at: file.url,
            tool: file.tool,
            claudeTypes: SessionMonitoringPolicy.claudeConversationTypes,
            steps: SessionMonitoringPolicy.stateTailByteSteps,
            isSufficient: { !$0.isEmpty }
        ).first
    }

    /// 모델과 사용량이 든 기록이 나올 때까지 읽는 범위를 단계적으로 넓힌다.
    func infoRecords(of file: LogFile) -> [JSONValue] {
        records(
            at: file.url,
            tool: file.tool,
            claudeTypes: SessionMonitoringPolicy.claudeInfoTypes,
            steps: SessionMonitoringPolicy.infoTailByteSteps,
            isSufficient: { hasUsageRecord(in: $0, tool: file.tool) }
        )
    }

    private func hasUsageRecord(in records: [JSONValue], tool: AiTool) -> Bool {
        switch tool {
        case .codex:
            records.contains { $0["payload"]?["type"]?.stringValue == "token_count" }
        case .claude:
            records.contains { $0["type"]?.stringValue == "assistant" && $0["message"]?["usage"] != nil }
        }
    }
}
