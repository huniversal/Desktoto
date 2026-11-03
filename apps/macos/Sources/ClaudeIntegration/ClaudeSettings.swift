import Foundation

enum ClaudeSettings {
    static let hookScript = "ai-run-hook.sh"
    static let statusScript = "ai-run-statusline.sh"

    static func parse(_ data: Data) throws -> [String: Any] {
        if data.allSatisfy({ [0x20, 0x0A, 0x0D, 0x09].contains($0) }) { return [:] }
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeIntegration.Failure.invalidSettings
        }
        return settings
    }

    static func serialize(_ settings: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    static func hasHook(_ settings: [String: Any]) -> Bool {
        let groups = (settings["hooks"] as? [String: Any])?["Notification"] as? [[String: Any]] ?? []
        return groups.contains { group in
            guard group["matcher"] as? String == "permission_prompt" else { return false }
            return (group["hooks"] as? [[String: Any]] ?? []).contains { hook in
                guard hook["type"] as? String == "command", let command = hook["command"] as? String,
                      let decoded = ownedCommand(command, script: hookScript) else { return false }
                return decoded.original == nil
            }
        }
    }

    static func hasStatusLine(_ settings: [String: Any], hasStatusSaver: (String) -> Bool) -> Bool {
        guard let status = settings["statusLine"] as? [String: Any], status["type"] as? String == "command",
              let command = status["command"] as? String else { return false }
        return command.contains(statusScript) || hasStatusSaver(command)
    }

    static func connecting(
        _ settings: [String: Any], hookPath: String, statusPath: String, hasStatusSaver: (String) -> Bool
    ) throws -> [String: Any] {
        var result = settings
        if !hasStatusLine(settings, hasStatusSaver: hasStatusSaver) {
            if let existing = settings["statusLine"] {
                guard var status = existing as? [String: Any], status["type"] as? String == "command",
                      let original = status["command"] as? String else { throw ClaudeIntegration.Failure.unsupportedStatusLine }
                status["command"] = "sh \(ShellQuote.encode(statusPath)) \(ShellQuote.encode(original))"
                result["statusLine"] = status
            } else {
                result["statusLine"] = ["type": "command", "command": "sh \(ShellQuote.encode(statusPath))"]
            }
        }
        if !hasHook(settings) {
            var hooks = try notificationHooks(settings)
            var groups = hooks["Notification"] as? [[String: Any]] ?? []
            groups.append(["matcher": "permission_prompt", "hooks": [
                ["type": "command", "command": "sh \(ShellQuote.encode(hookPath))"]
            ]])
            hooks["Notification"] = groups
            result["hooks"] = hooks
        }
        return result
    }

    static func disconnecting(_ settings: [String: Any]) throws -> [String: Any] {
        var result = settings
        if var status = settings["statusLine"] as? [String: Any],
           let command = status["command"] as? String, command.contains(statusScript) {
            guard status["type"] as? String == "command",
                  let decoded = ownedCommand(command, script: statusScript) else {
                // 외부 명령이 감싼 경우 hook까지 부분 해제하지 않고 전체 설정을 보존한다.
                throw ClaudeIntegration.Failure.cannotRestoreStatusLine
            }
            if let original = decoded.original {
                status["command"] = original
                result["statusLine"] = status
            } else {
                result.removeValue(forKey: "statusLine")
            }
        }
        if hasHook(settings) {
            var hooks = try notificationHooks(settings)
            let groups = hooks["Notification"] as? [[String: Any]] ?? []
            hooks["Notification"] = groups.compactMap { group -> [String: Any]? in
                guard group["matcher"] as? String == "permission_prompt" else { return group }
                var kept = group
                let original = group["hooks"] as? [[String: Any]] ?? []
                let remaining = original.filter { hook in
                    guard hook["type"] as? String == "command", let command = hook["command"] as? String,
                          let decoded = ownedCommand(command, script: hookScript) else { return true }
                    return decoded.original != nil
                }
                guard remaining.count != original.count else { return group }
                if remaining.isEmpty && Set(group.keys).isSubset(of: ["matcher", "hooks"]) { return nil }
                kept["hooks"] = remaining
                return kept
            }
            if (hooks["Notification"] as? [[String: Any]])?.isEmpty == true { hooks.removeValue(forKey: "Notification") }
            if hooks.isEmpty { result.removeValue(forKey: "hooks") } else { result["hooks"] = hooks }
        }
        return result
    }

    /// sh '<path>' ['<original command>']만 인정한다.
    static func ownedCommand(_ command: String, script: String) -> (path: String, original: String?)? {
        guard command.hasPrefix("sh "), let path = ShellQuote.decodePrefix(command.dropFirst(3)),
              (path.value as NSString).lastPathComponent == script else { return nil }
        if path.rest.isEmpty { return (path.value, nil) }
        guard path.rest.first == " ", let original = ShellQuote.decode(String(path.rest.dropFirst())) else { return nil }
        return (path.value, original)
    }

    private static func notificationHooks(_ settings: [String: Any]) throws -> [String: Any] {
        guard let raw = settings["hooks"] else { return [:] }
        guard let hooks = raw as? [String: Any] else { throw ClaudeIntegration.Failure.unsupportedHooks }
        if let rawGroups = hooks["Notification"] {
            guard let groups = rawGroups as? [[String: Any]], groups.allSatisfy({ group in
                group["hooks"] == nil || group["hooks"] is [[String: Any]]
            }) else { throw ClaudeIntegration.Failure.unsupportedHooks }
        }
        return hooks
    }
}
