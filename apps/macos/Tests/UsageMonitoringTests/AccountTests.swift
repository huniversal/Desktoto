import Boundaries
import Domain
import Foundation
import TestSupport
import Testing
@testable import UsageMonitoring

/// 설정 폴더(계정)마다 사용량이 하나씩 나오는지 합성 상태 파일로 확인한다.
struct AccountTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private let workDirectory = "/synthetic/claude-profiles/work/home"

    private func addStatus(_ files: InMemoryFileSystem, id: String, percent: Int, configDirectory: String?, age: TimeInterval) {
        let directory = files.homeDirectory.appendingPathComponent(".ai-run/status")
        let modifiedAt = now.addingTimeInterval(-age)
        files.addFile(at: directory.appendingPathComponent("\(id).json"), text: #"{"rate_limits":{"five_hour":{"used_percentage":\#(percent)}}}"#, modifiedAt: modifiedAt)
        if let configDirectory {
            files.addFile(at: directory.appendingPathComponent("\(id).config-dir"), text: configDirectory, modifiedAt: modifiedAt)
        }
    }

    private func getClaudeUsages(_ files: InMemoryFileSystem) async -> [ToolUsage] {
        let monitor = UsageMonitor(fileSystem: files, timeSource: FixedTimeSource(now: now))
        defer { Task { await monitor.stop() } }
        return await monitor.getUsages().filter { $0.tool == .claude }
    }

    @Test func eachConfigDirectoryGetsItsOwnUsageWithDefaultFirst() async {
        let files = InMemoryFileSystem()
        addStatus(files, id: "work-session", percent: 60, configDirectory: workDirectory, age: 1)
        addStatus(files, id: "default-session", percent: 30, configDirectory: files.homeDirectory.appendingPathComponent(".claude").path, age: 5)
        let usages = await getClaudeUsages(files)
        #expect(usages.map(\.account) == [nil, workDirectory])
        #expect(usages.map { $0.fiveHour?.usedRatio } == [0.3, 0.6])
        #expect(Set(usages.map(\.id)).count == 2)
    }

    @Test func newestFileWinsWithinOneAccount() async {
        let files = InMemoryFileSystem()
        addStatus(files, id: "old", percent: 10, configDirectory: workDirectory, age: 100)
        addStatus(files, id: "new", percent: 70, configDirectory: workDirectory, age: 1)
        let usages = await getClaudeUsages(files)
        #expect(usages.count == 1)
        #expect(usages.first?.fiveHour?.usedRatio == 0.7)
    }

    @Test func missingOrEmptyConfigDirectoryMeansDefaultAccount() async {
        let files = InMemoryFileSystem()
        addStatus(files, id: "legacy", percent: 20, configDirectory: nil, age: 1)
        addStatus(files, id: "blank", percent: 90, configDirectory: "  \n", age: 5)
        let usages = await getClaudeUsages(files)
        #expect(usages.count == 1)
        #expect(usages.first?.account == nil)
        #expect(usages.first?.fiveHour?.usedRatio == 0.2)
    }

    @Test func accountBehindManyNewerFilesOfAnotherAccountIsStillFound() async {
        let files = InMemoryFileSystem()
        for index in 0..<12 {
            addStatus(files, id: "default-\(index)", percent: 10, configDirectory: nil, age: Double(index + 1))
        }
        addStatus(files, id: "work", percent: 80, configDirectory: workDirectory, age: 500)
        let usages = await getClaudeUsages(files)
        #expect(usages.map(\.account) == [nil, workDirectory])
        #expect(usages.last?.fiveHour?.usedRatio == 0.8)
    }

    @Test func singleAccountKeepsSingleUsage() async {
        let files = InMemoryFileSystem()
        addStatus(files, id: "a", percent: 40, configDirectory: nil, age: 1)
        addStatus(files, id: "b", percent: 50, configDirectory: nil, age: 2)
        #expect(await getClaudeUsages(files).count == 1)
    }

    @Test func changedStatusFileIsReadAgain() async {
        let files = InMemoryFileSystem()
        addStatus(files, id: "a", percent: 40, configDirectory: workDirectory, age: 100)
        let monitor = UsageMonitor(fileSystem: files, timeSource: FixedTimeSource(now: now))
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.4)
        addStatus(files, id: "a", percent: 55, configDirectory: workDirectory, age: 1)
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.55)
        await monitor.stop()
    }
}
