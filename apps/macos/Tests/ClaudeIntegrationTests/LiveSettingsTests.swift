import Boundaries
import Foundation
import Testing
@testable import ClaudeIntegration

func temporaryIntegrationDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("desktoto-7 user's-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func integrationResources() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources")
}

struct LiveSettingsTests {
    @Test func linkTargetIsBackedUpAndLinkSurvivesRoundTrip() async throws {
        let root = try temporaryIntegrationDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = LiveSettingsFileSystem(homeDirectory: root)
        let target = root.appendingPathComponent("actual/settings.json")
        let link = root.appendingPathComponent(".claude/settings.json")
        let original = Data("{\"env\": {\"KEEP\": \"yes\"}}\n".utf8)
        try files.writeAtomically(original, to: target)
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../actual/settings.json")
        let service = ClaudeIntegration(fileSystem: files, resourceDirectory: integrationResources())
        #expect(await service.connect() == .connected)
        #expect(await service.connectionState() == .connected)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == "../actual/settings.json")
        #expect(try files.read(at: root.appendingPathComponent(".ai-run/bin/ai-run-hook.sh")) == Data(contentsOf: integrationResources().appendingPathComponent("ai-run-hook.sh")))
        #expect(await service.disconnect() == .disconnected)
        let restored = try ClaudeSettings.parse(try #require(try files.read(at: target)))
        #expect(NSDictionary(dictionary: restored).isEqual(to: try ClaudeSettings.parse(original)))
        let backups = try FileManager.default.contentsOfDirectory(at: target.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("backup") }
        #expect(backups.count == 2)
        #expect(try backups.contains { try Data(contentsOf: $0) == original })
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == "../actual/settings.json")
    }

    @Test func liveBoundaryDistinguishesMissingAndDeniedAndDoesNotOverwriteCopies() throws {
        let root = try temporaryIntegrationDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = LiveSettingsFileSystem(homeDirectory: root)
        let url = root.appendingPathComponent("settings.json")
        #expect(try files.read(at: url) == nil)
        #expect(try files.readPrefix(at: url, maxBytes: 5) == nil)
        try files.writeAtomically(Data("original".utf8), to: url)
        #expect(try files.readPrefix(at: url, maxBytes: 4) == Data("orig".utf8))
        let backup = root.appendingPathComponent("backup")
        try files.copyFile(at: url, to: backup)
        try files.writeAtomically(Data("changed".utf8), to: url)
        #expect(throws: CocoaError.self) { try files.copyFile(at: url, to: backup) }
        #expect(try files.read(at: backup) == Data("original".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
        #expect(throws: CocoaError.self) { try files.read(at: url) }
        #expect(throws: CocoaError.self) { try files.readPrefix(at: url, maxBytes: 4) }
    }
}
