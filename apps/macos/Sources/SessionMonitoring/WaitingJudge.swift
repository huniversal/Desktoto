import Boundaries
import Domain

/// 기록만으로 알 수 있는 응답 대기를 판정한다. Claude 기록만 대상이며 입출력이 없는 순수 함수다.
/// 답하기 전까지 도구 결과가 없는 질문(AskUserQuestion)과 계획 승인(ExitPlanMode),
/// 그리고 턴이 끝날 때 질문을 담은 다음 단계 상자(wrap_up의 ask)가 대상이다. 사용자가 답하면 새 입력이 쌓여서 자동으로 풀린다.
enum WaitingJudge {
    /// lastConversation은 마지막 대화 기록이다. infoRecords는 wrap_up을 찾아야 할 때만 호출한다.
    static func waitingKind(lastConversation: JSONValue, infoRecords: () -> [JSONValue]) -> WaitingKind? {
        guard lastConversation["type"]?.stringValue == "assistant" else { return nil }

        let toolNames = toolUseNames(in: lastConversation)
        if toolNames.contains("AskUserQuestion") { return .question }
        if toolNames.contains("ExitPlanMode") { return .approval }

        // 턴이 정상 종료됐고 그 턴에 질문이 담긴 다음 단계 상자가 있었다면 답을 기다리는 중이다.
        guard ActivityJudge.isEndTurn(stopReason: lastConversation["message"]?["stop_reason"]?.stringValue) else { return nil }
        return hasWrapUpQuestion(in: infoRecords()) ? .question : nil
    }

    private static func contentBlocks(of record: JSONValue) -> [JSONValue] {
        record["message"]?["content"]?.arrayValue ?? []
    }

    private static func toolUseNames(in record: JSONValue) -> Set<String> {
        Set(contentBlocks(of: record).compactMap { block in
            block["type"]?.stringValue == "tool_use" ? block["name"]?.stringValue : nil
        })
    }

    /// 최신순 기록에서 마지막 사용자 입력까지 거슬러 올라가며, 그 턴의 wrap_up이 비어 있지 않은 ask를 가졌는지 본다.
    private static func hasWrapUpQuestion(in records: [JSONValue]) -> Bool {
        for record in records {
            switch record["type"]?.stringValue {
            case "user":
                if isUserPrompt(record) { return false } // 이 턴이 시작된 곳까지 올라왔다.
            case "assistant":
                let hasQuestion = contentBlocks(of: record).contains { block in
                    guard block["type"]?.stringValue == "tool_use",
                          block["name"]?.stringValue?.hasSuffix("wrap_up") == true,
                          let ask = block["input"]?["ask"]?.stringValue else { return false }
                    return !ask.isEmpty
                }
                if hasQuestion { return true }
            default:
                continue
            }
        }
        return false
    }

    /// 도구 결과만 담긴 user 기록이 아니라, 사람이 입력한 글이 담긴 기록인지.
    private static func isUserPrompt(_ record: JSONValue) -> Bool {
        if record["message"]?["content"]?.stringValue != nil { return true }
        return contentBlocks(of: record).contains { $0["type"]?.stringValue == "text" }
    }
}
