import Boundaries
import Domain
import Foundation
import TestSupport
import Testing
@testable import UsageMonitoring

struct CacheBoundaryTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func waitFor(_ condition: () async -> Bool) async throws {
        for _ in 0..<20_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw CocoaError(.coderValueNotFound)
    }

    private func cacheFile(_ files: InMemoryFileSystem, name: String) -> URL {
        files.homeDirectory.appendingPathComponent("Library/Application Support/Claude/Cache/Cache_Data/\(name)")
    }

    private func validEntry(utilization: Int = 75, key: String = "https://claude.ai/api/organizations/abcd-1234/usage") -> Data {
        var bytes = UsageTests().entry(body: Data(#"{"five_hour":{"utilization":\#(utilization)}}"#.utf8), key: key)
        bytes.append(Data(repeating: 32, count: 500 - bytes.count))
        return bytes
    }

    private let base = "https://claude.ai/api/organizations/abcd-1234/usage"

    /// 데스크탑 캐시는 어느 계정의 값인지 알 수 없다. 기본 계정과만 겨루고, 다른 계정만 있으면 카드를 더하지 않는다.
    @Test func desktopCacheCompetesOnlyWithDefaultAccount() async throws {
        let files = InMemoryFileSystem()
        let status = files.homeDirectory.appendingPathComponent(".ai-run/status")
        let desktopCache = cacheFile(files, name: "desktop_0")
        files.addFile(at: desktopCache, data: validEntry(utilization: 75), modifiedAt: now.addingTimeInterval(-10))
        files.addFile(at: status.appendingPathComponent("work.json"), text: #"{"rate_limits":{"five_hour":{"used_percentage":20}}}"#, modifiedAt: now)
        files.addFile(at: status.appendingPathComponent("work.config-dir"), text: "/synthetic/work-config", modifiedAt: now)
        let monitor = UsageMonitor(fileSystem: files, timeSource: FixedTimeSource(now: now))
        // 탐색이 끝나 캐시 파일을 읽을 때까지 기다린 뒤에 단언해야 아래 결과가 의미를 가진다.
        try await waitFor {
            _ = await monitor.getUsages()
            return files.readCount(of: desktopCache) > 0
        }
        #expect(await monitor.getUsages().map(\.account) == ["/synthetic/work-config"])

        files.addFile(at: status.appendingPathComponent("home.json"), text: #"{"rate_limits":{"five_hour":{"used_percentage":30}}}"#, modifiedAt: now.addingTimeInterval(-60))
        let withDefault = await monitor.getUsages()
        #expect(withDefault.map(\.account) == [nil, "/synthetic/work-config"])
        #expect(withDefault.first?.fiveHour?.usedRatio == 0.75)
        await monitor.stop()
    }

    @Test func newestQueryVariantWinsAndFallsBackWhenCorrupted() async throws {
        let files = InMemoryFileSystem()
        let clock = FixedTimeSource(now: now)
        let plain = cacheFile(files, name: "plain_0")
        let variant = cacheFile(files, name: "variant_0")
        files.addFile(at: plain, data: validEntry(utilization: 10, key: base), modifiedAt: now.addingTimeInterval(-3600))
        files.addFile(at: variant, data: validEntry(utilization: 50, key: "\(base)?skip_spend=1"), modifiedAt: now.addingTimeInterval(-60))
        let monitor = UsageMonitor(fileSystem: files, timeSource: clock)
        _ = await monitor.getUsages()
        try await waitFor { await monitor.getUsages().first?.fiveHour?.usedRatio == 0.5 }
        // 더 최신 항목이 갱신되면 다음 조회에서 바뀐다.
        files.addFile(at: variant, data: validEntry(utilization: 60, key: "\(base)?skip_spend=1"), modifiedAt: now.addingTimeInterval(-30))
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.6)
        // 오래된 항목이 더 최신이 되면 그 값을 쓴다.
        files.addFile(at: plain, data: validEntry(utilization: 20, key: base), modifiedAt: now)
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.2)
        // 최신 항목이 손상되면 다음 항목으로 대체한다.
        files.addFile(at: plain, data: Data(repeating: 0, count: 500), modifiedAt: now.addingTimeInterval(1))
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.6)
        await monitor.stop()
    }

    @Test func newVariantIsPickedUpOnRediscovery() async throws {
        let files = InMemoryFileSystem()
        let clock = FixedTimeSource(now: now)
        files.addFile(at: cacheFile(files, name: "plain_0"), data: validEntry(utilization: 10, key: base), modifiedAt: now.addingTimeInterval(-3600))
        let monitor = UsageMonitor(fileSystem: files, timeSource: clock)
        _ = await monitor.getUsages()
        try await waitFor { await monitor.getUsages().first?.fiveHour?.usedRatio == 0.1 }
        files.addFile(at: cacheFile(files, name: "variant_0"), data: validEntry(utilization: 40, key: "\(base)?skip_spend=1"), modifiedAt: now)
        clock.advance(by: 120)
        try await waitFor { await monitor.getUsages().first?.fiveHour?.usedRatio == 0.4 }
        await monitor.stop()
    }

    @Test func failedDiscoveryWaits120Seconds() async throws {
        let files = InMemoryFileSystem()
        let clock = FixedTimeSource(now: now)
        let invalid = cacheFile(files, name: "bad_0")
        files.addFile(at: invalid, data: Data(repeating: 0, count: 500), modifiedAt: now)
        let monitor = UsageMonitor(fileSystem: files, timeSource: clock)
        _ = await monitor.getUsages()
        try await waitFor { files.readCount(of: invalid) == 1 }
        let valid = cacheFile(files, name: "good_0")
        files.addFile(at: valid, data: validEntry(), modifiedAt: now.addingTimeInterval(1))
        clock.advance(by: 119)
        for _ in 0..<20 {
            #expect(await monitor.getUsages().isEmpty)
            await Task.yield()
        }
        #expect(files.readCount(of: valid) == 0)
        clock.advance(by: 1)
        try await waitFor { await monitor.getUsages().first?.fiveHour?.usedRatio == 0.75 }
        await monitor.stop()
    }

    @Test func discoveryChecksOnly600NewestEligibleFiles() async throws {
        let files = InMemoryFileSystem()
        let clock = FixedTimeSource(now: now)
        let oldest = cacheFile(files, name: "old_0")
        files.addFile(at: oldest, data: validEntry(), modifiedAt: now.addingTimeInterval(-1))
        for index in 0..<600 {
            files.addFile(at: cacheFile(files, name: "invalid\(index)_0"), data: Data(repeating: 0, count: 500), modifiedAt: now.addingTimeInterval(Double(index)))
        }
        // 이름과 크기가 맞지 않는 최신 항목은 600개 제한을 소모하지 않는다.
        files.addFile(at: cacheFile(files, name: "ignored_1"), data: validEntry(), modifiedAt: now.addingTimeInterval(1000))
        files.addFile(at: cacheFile(files, name: "small_0"), data: Data(repeating: 0, count: 499), modifiedAt: now.addingTimeInterval(1000))
        files.addFile(at: cacheFile(files, name: "large_0"), data: Data(repeating: 0, count: 65_537), modifiedAt: now.addingTimeInterval(1000))
        let monitor = UsageMonitor(fileSystem: files, timeSource: clock)
        _ = await monitor.getUsages()
        try await waitFor { files.readCount(of: cacheFile(files, name: "invalid0_0")) == 1 }
        #expect(files.readCount(of: oldest) == 0)
        let newest = cacheFile(files, name: "new_0")
        files.addFile(at: newest, data: validEntry(), modifiedAt: now.addingTimeInterval(2000))
        clock.advance(by: 120)
        try await waitFor { await monitor.getUsages().first?.fiveHour?.usedRatio == 0.75 }
        #expect(files.readCount(of: oldest) == 0)
        #expect(files.readCount(of: cacheFile(files, name: "ignored_1")) == 0)
        #expect(files.readCount(of: cacheFile(files, name: "small_0")) == 0)
        #expect(files.readCount(of: cacheFile(files, name: "large_0")) == 0)
        await monitor.stop()
    }

    @Test func rolloutExpandsReadAndCachesMissingValueUntilModification() async throws {
        let files = InMemoryFileSystem()
        let clock = FixedTimeSource(now: now)
        let url = files.homeDirectory.appendingPathComponent(".codex/sessions/a.jsonl")
        let record = #"{"payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":20,"window_minutes":300}}}}"#
        let padding = String(repeating: "x", count: 600_000)
        files.addFile(at: url, text: record + "\n" + padding + "\n", modifiedAt: now)
        let monitor = UsageMonitor(fileSystem: files, timeSource: clock)
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.2)
        #expect(files.readCount(of: url) == 3)
        _ = await monitor.getUsages()
        #expect(files.readCount(of: url) == 3)
        files.addFile(at: url, text: "broken", modifiedAt: now.addingTimeInterval(1))
        #expect(await monitor.getUsages().isEmpty)
        let missingReads = files.readCount(of: url)
        #expect(await monitor.getUsages().isEmpty)
        #expect(files.readCount(of: url) == missingReads)
        files.addFile(at: url, text: record + "\n", modifiedAt: now.addingTimeInterval(2))
        #expect(await monitor.getUsages().first?.fiveHour?.usedRatio == 0.2)
        await monitor.stop()
    }

    private func repeatedFrame(size: Int) -> Data {
        // 크기가 큰 합성 입력을 저장하지 않도록 RLE 블록들로 프레임을 만든다.
        var frame = Data([0x28, 0xb5, 0x2f, 0xfd, 0xa0])
        for index in 0..<4 { frame.append(UInt8(truncatingIfNeeded: size >> (index * 8))) }
        var remaining = size
        while remaining > 0 {
            let blockSize = min(remaining, 131_072)
            remaining -= blockSize
            let header = blockSize << 3 | 2 | (remaining == 0 ? 1 : 0)
            frame.append(contentsOf: (0..<3).map { UInt8(truncatingIfNeeded: header >> ($0 * 8)) })
            frame.append(32)
        }
        return frame
    }

    @Test func decompressionAcceptsLimitAndRejectsOneByteOver() {
        #expect(ClaudeCacheParser.decompress(repeatedFrame(size: 1_048_576))?.count == 1_048_576)
        #expect(ClaudeCacheParser.decompress(repeatedFrame(size: 1_048_577)) == nil)
        #expect(ClaudeCacheParser.decompress(Data([0x28, 0xb5, 0x2f, 0xfd, 0xff])) == nil)
    }
}
