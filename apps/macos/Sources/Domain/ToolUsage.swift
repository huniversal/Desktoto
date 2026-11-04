import Foundation

public struct ToolUsage: Sendable, Equatable, Identifiable {
    public let tool: AiTool
    /// 같은 툴의 계정을 구분하는 설정 폴더 경로. 기본 계정이거나 구분할 수 없으면 nil이다.
    public let account: String?
    public let fiveHour: UsageWindow?
    public let weekly: UsageWindow?
    public let updatedAt: Date?

    public var id: String { "\(tool.rawValue):\(account ?? "")" }

    public init(tool: AiTool, account: String? = nil, fiveHour: UsageWindow?, weekly: UsageWindow?, updatedAt: Date?) {
        self.tool = tool
        self.account = account
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.updatedAt = updatedAt
    }

    public func resetAware(at now: Date) -> Self {
        Self(tool: tool, account: account, fiveHour: fiveHour?.resetAware(at: now), weekly: weekly?.resetAware(at: now), updatedAt: updatedAt)
    }

    public func createStaleText(now: Date) -> String? {
        guard let updatedAt, now.timeIntervalSince(updatedAt) >= 600 else { return nil }
        let minutes = Int(now.timeIntervalSince(updatedAt) / 60)
        if minutes < 60 { return "\(minutes)분 전 기준" }
        if minutes < 1440 { return "\(minutes / 60)시간 전 기준" }
        return "\(minutes / 1440)일 전 기준"
    }
}
