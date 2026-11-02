import Domain
import Foundation

// 패널에 보이는 글자를 만드는 순수 함수. 시간은 호출하는 쪽이 now로 넘긴다.
enum PanelText {
    // 컨텍스트 사용률. 사용 토큰과 창 크기를 모두 알고 창 크기가 0보다 클 때만 만든다.
    static func usageRatio(of session: SessionInfo) -> Double? {
        guard let usedTokens = session.usedTokens, let windowTokens = session.windowTokens, windowTokens > 0 else {
            return nil
        }
        return min(Double(usedTokens) / Double(windowTokens), 1)
    }

    static func tokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000
            return millions.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(millions))M" : String(format: "%.1fM", millions)
        }
        return count >= 1000 ? "\(count / 1000)K" : "\(count)"
    }

    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    // 줄 오른쪽의 사용률. 창 크기를 추정한 값에는 ~를 붙인다.
    static func trailing(of session: SessionInfo) -> String {
        guard let ratio = usageRatio(of: session) else { return "-" }
        return "\(estimateMark(of: session))\(percent(ratio))"
    }

    // 마우스를 올렸을 때 보이는 "사용 토큰 / 창 토큰"
    static func tokenUsage(of session: SessionInfo) -> String {
        guard let usedTokens = session.usedTokens, let windowTokens = session.windowTokens else { return "-" }
        return "\(tokenCount(usedTokens)) / \(estimateMark(of: session))\(tokenCount(windowTokens))"
    }

    static func modelName(of session: SessionInfo) -> String {
        session.modelName ?? "모델 알 수 없음"
    }

    static func title(of session: SessionInfo) -> String {
        session.title ?? session.projectName
    }

    static func waitingPill(_ kind: WaitingKind) -> String {
        kind == .question ? "답변 필요" : "승인 필요"
    }

    // 초기화까지 남은 시간. 1시간 미만은 분, 하루 미만은 시간과 분, 그 이상은 일과 시간으로 보여준다.
    static func resetRemaining(until resetsAt: Date?, now: Date) -> String {
        guard let resetsAt else { return "" }
        let totalMinutes = max(Int(resetsAt.timeIntervalSince(now) / 60), 0)
        let (days, hours, minutes) = (totalMinutes / 1440, totalMinutes % 1440 / 60, totalMinutes % 60)
        if days > 0 { return "\(days)일 \(hours)시간" }
        if hours > 0 { return "\(hours)시간 \(minutes)분" }
        return "\(minutes)분"
    }

    // 창 크기를 확정하지 못하고 추정한 값에는 ~를 붙인다.
    private static func estimateMark(of session: SessionInfo) -> String {
        session.isWindowEstimated ? "~" : ""
    }
}
