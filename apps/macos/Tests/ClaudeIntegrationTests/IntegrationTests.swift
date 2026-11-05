import Boundaries
import Foundation
import TestSupport
import Testing
@testable import ClaudeIntegration

struct IntegrationTests {
    private let home = URL(fileURLWithPath: "/synthetic-home")
    private var settings: URL { home.appendingPathComponent(".claude/settings.json") }
    private let resources = URL(fileURLWithPath: "/synthetic-resources")

    private func service(_ files: InMemorySettingsFileSystem) -> ClaudeIntegration {
        ClaudeIntegration(fileSystem: files, resourceDirectory: resources, timeSource: FixedTimeSource(now: Date(timeIntervalSince1970: 0)))
    }

    private func installResources(_ files: InMemorySettingsFileSystem) {
        for name in [ClaudeSettings.hookScript, ClaudeSettings.statusScript] {
            files.setFile(Data("synthetic \(name)".utf8), at: resources.appendingPathComponent(name))
        }
    }

    private func writeCount(_ files: InMemorySettingsFileSystem) -> Int {
        files.operations.filter {
            switch $0 {
            case .write, .copy: true
            case .read, .prefix: false
            }
        }.count
    }

    private func isFailure(_ result: ClaudeIntegration.Result) -> Bool {
        if case .failed = result { return true }
        return false
    }

    @Test func lifecycleIsIdempotentAndBackupsNeverOverwrite() async throws {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        let original = Data("{\"env\": {\"KEEP\": \"yes\"}}\n".utf8)
        files.setFile(original, at: settings)
        let integration = service(files)
        #expect(await integration.connect() == .connected)
        let connected = try #require(files.files[settings])
        #expect(await integration.connectionState() == .connected)
        #expect(await integration.connect() == .alreadyConnected)
        #expect(files.operations.filter { if case .write = $0 { return true }; return false }.count == 3)
        #expect(await integration.disconnect() == .disconnected)
        #expect(await integration.connectionState() == .disconnected)
        #expect(await integration.disconnect() == .alreadyDisconnected)
        let backups = files.files.filter { $0.key.lastPathComponent.contains(".ai-run-backup-") }
        #expect(backups.count == 2)
        #expect(backups.values.contains(original))
        #expect(backups.values.contains(connected))
        #expect(backups.keys.contains { $0.lastPathComponent.hasSuffix("-2") })
    }

    @Test func connectedUserGetsInstalledScriptsReplacedOnlyWhenBundleDiffers() async throws {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        let integration = service(files)
        #expect(await integration.connect() == .connected)
        let settingsAfterConnect = try #require(files.files[settings])
        let installedStatus = home.appendingPathComponent(".ai-run/bin/\(ClaudeSettings.statusScript)")
        let installedHook = home.appendingPathComponent(".ai-run/bin/\(ClaudeSettings.hookScript)")
        let writesBefore = writeCount(files)
        #expect(await integration.connect() == .alreadyConnected)
        #expect(writeCount(files) == writesBefore)

        files.setFile(Data("old status script".utf8), at: installedStatus)
        #expect(await integration.connect() == .alreadyConnected)
        #expect(files.files[installedStatus] == Data("synthetic \(ClaudeSettings.statusScript)".utf8))
        #expect(files.files[installedHook] == Data("synthetic \(ClaudeSettings.hookScript)".utf8))
        #expect(files.files[settings] == settingsAfterConnect)
        #expect(!files.operations.contains { if case .copy = $0 { return true }; return false })
    }

    @Test func alreadyConnectedWithoutInstalledScriptsDoesNotCreateThem() async throws {
        let source = InMemorySettingsFileSystem()
        installResources(source)
        #expect(await service(source).connect() == .connected)
        let files = InMemorySettingsFileSystem()
        installResources(files)
        files.setFile(try #require(source.files[settings]), at: settings)
        #expect(await service(files).connect() == .alreadyConnected)
        #expect(files.files[home.appendingPathComponent(".ai-run/bin/\(ClaudeSettings.statusScript)")] == nil)
        #expect(writeCount(files) == 0)
    }

    @Test func absentSettingsAreCreatedWithoutBackup() async {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        #expect(await service(files).connect() == .connected)
        #expect(files.files[settings] != nil)
        #expect(!files.operations.contains { if case .copy = $0 { return true }; return false })
    }

    @Test(arguments: ["{broken", "[]", "null"])
    func invalidFilesHaveNoSideEffects(_ input: String) async {
        let files = InMemorySettingsFileSystem()
        files.setFile(Data(input.utf8), at: settings)
        let snapshot = files.files
        #expect(await service(files).connect() == .failed(.invalidSettings))
        #expect(await service(files).disconnect() == .failed(.invalidSettings))
        #expect(files.files == snapshot)
    }

    @Test func unreadableFileIsNotMistakenForMissing() async {
        let files = InMemorySettingsFileSystem(failReadAt: settings)
        installResources(files)
        let snapshot = files.files
        #expect(isFailure(await service(files).connect()))
        #expect(isFailure(await service(files).disconnect()))
        #expect(files.files == snapshot)
    }

    @Test func backupFailureDoesNotWriteSettings() async {
        let files = InMemorySettingsFileSystem(failsCopy: true)
        installResources(files)
        files.setFile(Data("{}".utf8), at: settings)
        #expect(isFailure(await service(files).connect()))
        #expect(files.files[settings] == Data("{}".utf8))
        #expect(!files.operations.contains(.write(settings)))
    }

    @Test func settingsWriteFailureKeepsOriginalAndBackup() async {
        let files = InMemorySettingsFileSystem(failWriteAt: settings)
        installResources(files)
        let original = Data("{}".utf8)
        files.setFile(original, at: settings)
        #expect(isFailure(await service(files).connect()))
        #expect(files.files[settings] == original)
        #expect(files.files.contains { $0.key.lastPathComponent.contains("backup") && $0.value == original })
    }

    @Test func missingOrUnwritableScriptsPreventSettingsWrite() async {
        let files = InMemorySettingsFileSystem()
        #expect(await service(files).connect() == .failed(.missingScript(ClaudeSettings.hookScript)))
        #expect(files.files.isEmpty)
        files.setFile(Data(), at: resources.appendingPathComponent(ClaudeSettings.hookScript))
        #expect(await service(files).connect() == .failed(.missingScript(ClaudeSettings.statusScript)))
        #expect(!files.operations.contains { if case .write = $0 { return true }; return false })
        let failing = InMemorySettingsFileSystem(failWriteAt: home.appendingPathComponent(".ai-run/bin/ai-run-hook.sh"))
        installResources(failing)
        #expect(isFailure(await service(failing).connect()))
        #expect(failing.files[settings] == nil)
    }

    @Test func startupHonorsDisabledPreferenceAfterDisconnect() async throws {
        let files = InMemorySettingsFileSystem()
        let integration = service(files)
        #expect(await integration.connectOnStartup(ifAllowed: false) == .skipped)
        #expect(files.operations.isEmpty)
        #expect(await integration.connectOnStartup(ifAllowed: true) == .skipped)
        installResources(files)
        #expect(await integration.connect() == .connected)
        #expect(await integration.disconnect() == .disconnected)
        let snapshot = files.files
        let count = files.operations.count
        #expect(await integration.connectOnStartup(ifAllowed: false) == .skipped)
        #expect(files.files == snapshot)
        #expect(files.operations.count == count)
    }

    @Test func foreignWrapperCannotPartiallyDisconnect() async throws {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        #expect(await service(files).connect() == .connected)
        var object = try ClaudeSettings.parse(try #require(files.files[settings]))
        object["statusLine"] = ["type": "command", "command": "sh -c \"sh '/tmp/ai-run-statusline.sh' 'printf hello'\""]
        files.setFile(try ClaudeSettings.serialize(object), at: settings)
        let snapshot = files.files
        #expect(await service(files).disconnect() == .failed(.cannotRestoreStatusLine))
        #expect(files.files == snapshot)
    }

    @Test func userStatusSaverIsDetectedWithBoundedRead() async throws {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        let script = home.appendingPathComponent("my scripts/status.sh")
        files.setFile(Data("# save ~/.ai-run/status".utf8), at: script)
        files.setFile(try ClaudeSettings.serialize(["statusLine": ["type": "command", "command": "sh \(ShellQuote.encode(script.path))"]]), at: settings)
        #expect(await service(files).connectionState() == .partial(hook: false, statusLine: true))
        #expect(await service(files).connect() == .connected)
        #expect(files.operations.contains(.prefix(script, 65_536)))
        let connected = try ClaudeSettings.parse(try #require(files.files[settings]))
        #expect((connected["statusLine"] as? [String: Any])?["command"] as? String == "sh \(ShellQuote.encode(script.path))")
    }

    @Test func concurrentConnectionsSerializeWithoutDuplicateBackups() async {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        files.setFile(Data("{}".utf8), at: settings)
        let integration = service(files)
        async let first = integration.connect()
        async let second = integration.connect()
        let results = await [first, second]
        #expect(results.contains(.connected))
        #expect(results.contains(.alreadyConnected))
        #expect(files.files.keys.filter { $0.lastPathComponent.contains("backup") }.count == 1)
    }

    @Test(arguments: [true, false])
    func disconnectFailuresPreserveConnectedSettings(_ backupFails: Bool) async throws {
        let files = InMemorySettingsFileSystem(failWriteAt: backupFails ? nil : settings, failsCopy: backupFails)
        let connected = try ClaudeSettings.connecting([:], hookPath: "/bin/ai-run-hook.sh", statusPath: "/bin/ai-run-statusline.sh", hasStatusSaver: { _ in false })
        let original = try ClaudeSettings.serialize(connected)
        files.setFile(original, at: settings)
        #expect(isFailure(await service(files).disconnect()))
        #expect(files.files[settings] == original)
        #expect(await service(files).connectionState() == .connected)
    }

    @Test func legacyConnectionNeedsNoResourcesAndPartialStateCanBeRepaired() async throws {
        let files = InMemorySettingsFileSystem()
        let connected = try ClaudeSettings.connecting([:], hookPath: "/bin/ai-run-hook.sh", statusPath: "/bin/ai-run-statusline.sh", hasStatusSaver: { _ in false })
        files.setFile(try ClaudeSettings.serialize(connected), at: settings)
        #expect(await service(files).connect() == .alreadyConnected)
        #expect(writeCount(files) == 0)
        var partial = connected
        partial.removeValue(forKey: "statusLine")
        files.setFile(try ClaudeSettings.serialize(partial), at: settings)
        #expect(await service(files).connectionState() == .partial(hook: true, statusLine: false))
        installResources(files)
        #expect(await service(files).connectOnStartup(ifAllowed: true) == .connected)
        #expect(await service(files).connectionState() == .connected)
    }

    @Test func saverMarkerBeyondLimitDoesNotSuppressWrapper() async throws {
        let files = InMemorySettingsFileSystem()
        installResources(files)
        let script = home.appendingPathComponent("large-status.sh")
        var contents = Data(repeating: 0x20, count: 65_536)
        contents.append(Data(".ai-run/status".utf8))
        files.setFile(contents, at: script)
        files.setFile(try ClaudeSettings.serialize(["statusLine": ["type": "command", "command": "sh \(ShellQuote.encode(script.path))"]]), at: settings)
        #expect(await service(files).connectionState() == .disconnected)
        #expect(await service(files).connect() == .connected)
        let updated = try ClaudeSettings.parse(try #require(files.files[settings]))
        #expect(((updated["statusLine"] as? [String: Any])?["command"] as? String)?.contains(ClaudeSettings.statusScript) == true)
    }
}
