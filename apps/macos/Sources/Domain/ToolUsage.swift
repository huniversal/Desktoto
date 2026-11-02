import Foundation

public struct ToolUsage: Sendable, Equatable {
    public let tool: AiTool
    public let fiveHour: UsageWindow?
    public let weekly: UsageWindow?
    public let updatedAt: Date?

    public init(tool: AiTool, fiveHour: UsageWindow?, weekly: UsageWindow?, updatedAt: Date?) {
        self.tool = tool
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.updatedAt = updatedAt
    }

    public func resetAware(at now: Date) -> Self {
        Self(tool: tool, fiveHour: fiveHour?.resetAware(at: now), weekly: weekly?.resetAware(at: now), updatedAt: updatedAt)
    }

    public func createStaleText(now: Date) -> String? {
        guard let updatedAt, now.timeIntervalSince(updatedAt) >= 600 else { return nil }
        let minutes = Int(now.timeIntervalSince(updatedAt) / 60)
        if minutes < 60 { return "\(minutes)분 전 기준" }
        if minutes < 1440 { return "\(minutes / 60)시간 전 기준" }
        return "\(minutes / 1440)일 전 기준"
    }
}
