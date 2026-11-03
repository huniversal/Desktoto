import Boundaries
import Foundation
import TestSupport
import Testing
@testable import TerminalIntegration

struct ClaudeDesktopSessionLinksTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func metadataURL(_ fileSystem: InMemoryFileSystem, name: String) -> URL {
        fileSystem.homeDirectory.appendingPathComponent("Library/Application Support/Claude/claude-code-sessions/account/\(name).json")
    }

    // AC-11
    @Test func mapsCLISessionIDToDesktopLink() {
        let fileSystem = InMemoryFileSystem()
        fileSystem.addFile(at: metadataURL(fileSystem, name: "a"), text: #"{"sessionId": "local_1", "cliSessionId": "cli-1"}"#, modifiedAt: now)
        fileSystem.addFile(at: metadataURL(fileSystem, name: "bad"), text: "garbage", modifiedAt: now)
        fileSystem.addFile(at: metadataURL(fileSystem, name: "partial"), text: #"{"sessionId": "local_2"}"#, modifiedAt: now)
        let links = ClaudeDesktopSessionLinks(fileSystem: fileSystem, timeSource: FixedTimeSource(now: now))

        #expect(links.url(forSessionID: "cli-1") == URL(string: "claude://claude.ai/epitaxy/local_1"))
        #expect(links.url(forSessionID: "unknown") == nil)
    }

    // AC-11
    @Test func returnsNilWhenFolderIsMissing() {
        let links = ClaudeDesktopSessionLinks(fileSystem: InMemoryFileSystem(), timeSource: FixedTimeSource(now: now))
        #expect(links.url(forSessionID: "cli-1") == nil)
    }

    // AC-11
    @Test func doesNotReloadWithinTenSecondsForMissingSession() {
        let fileSystem = InMemoryFileSystem()
        let timeSource = FixedTimeSource(now: now)
        let links = ClaudeDesktopSessionLinks(fileSystem: fileSystem, timeSource: timeSource)
        #expect(links.url(forSessionID: "cli-1") == nil)

        let url = metadataURL(fileSystem, name: "a")
        fileSystem.addFile(at: url, text: #"{"sessionId": "local_1", "cliSessionId": "cli-1"}"#, modifiedAt: now)
        timeSource.advance(by: 5)
        #expect(links.url(forSessionID: "cli-1") == nil)
        timeSource.advance(by: 6)
        #expect(links.url(forSessionID: "cli-1") != nil)
    }

    // AC-11
    @Test func doesNotReadFilesAgainOnceSessionIsMapped() {
        let fileSystem = InMemoryFileSystem()
        let url = metadataURL(fileSystem, name: "a")
        fileSystem.addFile(at: url, text: #"{"sessionId": "local_1", "cliSessionId": "cli-1"}"#, modifiedAt: now)
        let timeSource = FixedTimeSource(now: now)
        let links = ClaudeDesktopSessionLinks(fileSystem: fileSystem, timeSource: timeSource)

        _ = links.url(forSessionID: "cli-1")
        timeSource.advance(by: 60)
        _ = links.url(forSessionID: "cli-1")

        #expect(fileSystem.readCount(of: url) == 1)
    }
}
