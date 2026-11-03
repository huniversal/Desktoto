import Foundation
import Testing
@testable import ClaudeIntegration

struct SettingsTransformTests {
    private func connect(_ settings: [String: Any]) throws -> [String: Any] {
        try ClaudeSettings.connecting(settings, hookPath: "/bin/ai-run-hook.sh", statusPath: "/bin/ai-run-statusline.sh", hasStatusSaver: { _ in false })
    }

    @Test(arguments: ["", "hello world's", "\"$HOME\" `pwd` \\ backslash", "line1\nline2", "한글 '경로'", "'''"])
    func shellQuoteRoundTrip(_ original: String) {
        #expect(ShellQuote.decode(ShellQuote.encode(original)) == original)
    }

    @Test(arguments: ["'unterminated", "'ok' ; echo changed", "plain", "'ok'\"other\""])
    func rejectsShellExpressions(_ command: String) {
        #expect(ShellQuote.decode(command) == nil)
    }

    @Test func restoresUserStatusLineAndPreservesOtherSettings() throws {
        let original: [String: Any] = [
            "statusLine": ["type": "command", "command": "printf '%s\\n' \"hello world's\"", "padding": 3],
            "env": ["SYNTHETIC": "test"], "unknown": ["enabled": true, "count": 3]
        ]
        let connected = try connect(original)
        #expect(ClaudeSettings.hasHook(connected))
        #expect(ClaudeSettings.hasStatusLine(connected, hasStatusSaver: { _ in false }))
        #expect(NSDictionary(dictionary: try connect(connected)).isEqual(to: connected))
        #expect(NSDictionary(dictionary: try ClaudeSettings.disconnecting(connected)).isEqual(to: original))
    }

    @Test func removesOnlyOwnedHookFromSharedGroup() throws {
        let owned: [String: Any] = ["type": "command", "command": "sh '/bin/ai-run-hook.sh'"]
        let other: [String: Any] = ["type": "command", "command": "echo 'ai-run-hook.sh'"]
        let original: [String: Any] = ["hooks": [
            "Notification": [["matcher": "permission_prompt", "hooks": [owned, other], "custom": true],
                             ["matcher": "other", "hooks": [owned]]],
            "Stop": [["hooks": [other]]]
        ]]
        let updated = try ClaudeSettings.disconnecting(original)
        let hooks = try #require(updated["hooks"] as? [String: Any])
        let groups = try #require(hooks["Notification"] as? [[String: Any]])
        #expect(groups.count == 2)
        #expect((groups[0]["hooks"] as? [[String: Any]])?.count == 1)
        #expect(groups[0]["custom"] as? Bool == true)
        #expect((groups[1]["hooks"] as? [[String: Any]])?.count == 1)
        #expect(hooks["Stop"] != nil)
    }

    @Test func retainsCustomGroupMetadataWhenLastHookRemoved() throws {
        let original: [String: Any] = ["hooks": ["Notification": [[
            "matcher": "permission_prompt", "metadata": "keep", "hooks": [
                ["type": "command", "command": "sh '/bin/ai-run-hook.sh'"]
            ]
        ]]]]
        let updated = try ClaudeSettings.disconnecting(original)
        let groups = try #require((updated["hooks"] as? [String: Any])?["Notification"] as? [[String: Any]])
        #expect(groups.first?["metadata"] as? String == "keep")
        #expect((groups.first?["hooks"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test func rejectsForeignWrapperBeforeRemovingHook() throws {
        var settings = try connect([:])
        settings["statusLine"] = ["type": "command", "command": "sh -c \"sh '/bin/ai-run-statusline.sh' 'printf hello'\""]
        #expect(throws: ClaudeIntegration.Failure.cannotRestoreStatusLine) {
            try ClaudeSettings.disconnecting(settings)
        }
        #expect(ClaudeSettings.hasHook(settings))
    }

    @Test func preservesUserSaverAndUnsupportedStatusLine() throws {
        let custom: [String: Any] = ["statusLine": ["type": "command", "command": "sh '/custom.sh'", "padding": 2]]
        let result = try ClaudeSettings.connecting(custom, hookPath: "/bin/ai-run-hook.sh", statusPath: "/bin/ai-run-statusline.sh", hasStatusSaver: { _ in true })
        #expect(NSDictionary(dictionary: try ClaudeSettings.disconnecting(result)).isEqual(to: custom))
        #expect(throws: ClaudeIntegration.Failure.unsupportedStatusLine) { try connect(["statusLine": ["type": "future", "value": 1]]) }
        #expect(throws: ClaudeIntegration.Failure.unsupportedStatusLine) { try connect(["statusLine": NSNull()]) }
    }

    @Test(arguments: ["broken", "[]", "null", "true"])
    func refusesInvalidSettings(_ input: String) {
        #expect(throws: ClaudeIntegration.Failure.invalidSettings) { try ClaudeSettings.parse(Data(input.utf8)) }
    }

    @Test func refusesMalformedHooksWithoutOverwritingThem() {
        #expect(throws: ClaudeIntegration.Failure.unsupportedHooks) { try connect(["hooks": ["Notification": "future"]]) }
        #expect(throws: ClaudeIntegration.Failure.unsupportedHooks) { try connect(["hooks": ["Notification": [["hooks": "future"]]]]) }
    }

    @Test func emptySettingsAndInjectedPaths() throws {
        #expect(try ClaudeSettings.parse(Data(" \r\n\t".utf8)).isEmpty)
        let hookPath = "/tmp/user's bin/ai-run-hook.sh"
        let statusPath = "/tmp/user's bin/ai-run-statusline.sh"
        let settings = try ClaudeSettings.connecting([:], hookPath: hookPath, statusPath: statusPath, hasStatusSaver: { _ in false })
        let status = try #require(settings["statusLine"] as? [String: Any])
        #expect(ClaudeSettings.ownedCommand(try #require(status["command"] as? String), script: ClaudeSettings.statusScript)?.path == statusPath)
        #expect(ClaudeSettings.hasHook(settings))
        #expect(try ClaudeSettings.disconnecting(settings).isEmpty)
    }
}
