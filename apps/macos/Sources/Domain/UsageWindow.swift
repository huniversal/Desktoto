import Foundation

public struct UsageWindow: Sendable, Equatable {
    public let usedRatio: Double
    public let resetsAt: Date?

    public init(usedRatio: Double, resetsAt: Date?) {
        self.usedRatio = usedRatio
        self.resetsAt = resetsAt
    }

    public func resetAware(at now: Date) -> Self {
        guard let resetsAt, resetsAt <= now else { return self }
        return Self(usedRatio: 0, resetsAt: nil)
    }
}
