import Boundaries
import Domain
import Foundation

public enum UsageParser {
    static func number(_ value: JSONValue?) -> Double? {
        guard case .number(let number) = value else { return nil }
        return number
    }

    public static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: text.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }

    static func window(_ value: JSONValue?, percent: String, reset: String, isoDate: Bool = false) -> UsageWindow? {
        guard let value, let percent = number(value[percent]) else { return nil }
        let date = isoDate ? value[reset]?.stringValue.flatMap(parseDate) : number(value[reset]).map(Date.init(timeIntervalSince1970:))
        return UsageWindow(usedRatio: min(max(percent / 100, 0), 1), resetsAt: date)
    }

    public static func claude(_ limits: JSONValue, desktop: Bool, updatedAt: Date?) -> ToolUsage? {
        let percent = desktop ? "utilization" : "used_percentage"
        let five = window(limits["five_hour"], percent: percent, reset: "resets_at", isoDate: desktop)
        let weekly = window(limits["seven_day"], percent: percent, reset: "resets_at", isoDate: desktop)
        guard five != nil || weekly != nil else { return nil }
        return ToolUsage(tool: .claude, fiveHour: five, weekly: weekly, updatedAt: updatedAt)
    }

    public static func codex(_ limits: JSONValue, live: Bool, updatedAt: Date?) -> ToolUsage? {
        var five: UsageWindow?
        var weekly: UsageWindow?
        for key in ["primary", "secondary"] {
            guard let value = limits[key], let minutes = number(value[live ? "windowDurationMins" : "window_minutes"]) else { continue }
            if live, number(value["usedPercent"]) == nil { continue }
            let parsed = window(value, percent: live ? "usedPercent" : "used_percent", reset: live ? "resetsAt" : "resets_at")
            if minutes <= 600 { five = parsed } else if minutes >= 7200 { weekly = parsed }
        }
        guard five != nil || weekly != nil else { return nil }
        return ToolUsage(tool: .codex, fiveHour: five, weekly: weekly, updatedAt: updatedAt)
    }

    public static func takeCompleteLines(from buffer: inout Data) -> [Data] {
        var lines: [Data] = []
        while let index = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<index])
            buffer.removeSubrange(...index)
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }
}
