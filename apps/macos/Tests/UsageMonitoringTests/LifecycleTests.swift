import Boundaries
import Domain
import Foundation
import Synchronization
import TestSupport
import Testing
@testable import UsageMonitoring

private actor DelayGate {
    private var waiters: [Int: (Double, CheckedContinuation<Void, Error>)] = [:]
    private var nextID = 0

    func sleep(_ seconds: Double) async throws {
        nextID += 1
        let id = nextID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else { waiters[id] = (seconds, continuation) }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func cancel(_ id: Int) {
        waiters.removeValue(forKey: id)?.1.resume(throwing: CancellationError())
    }

    func contains(_ seconds: Double) -> Bool { waiters.values.contains { $0.0 == seconds } }
    func release(_ seconds: Double) {
        let matching = waiters.filter { $0.value.0 == seconds }
        for (id, waiter) in matching {
            waiters.removeValue(forKey: id)
            waiter.1.resume()
        }
    }
}

struct LifecycleTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func waitFor(_ condition: @escaping () async -> Bool) async throws {
        // yield 횟수는 CPU가 바쁠 때 금방 소진되므로 마감 시간까지 짧게 쉬면서 기다린다.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw CocoaError(.coderValueNotFound)
    }

    private func files() -> InMemoryFileSystem {
        let files = InMemoryFileSystem()
        files.addFile(at: files.homeDirectory.appendingPathComponent(".local/bin/codex"), text: "", modifiedAt: now)
        return files
    }

    @Test func timeoutBackoffAndLateOutput() async throws {
        let launcher = ScriptedProcessLauncher { _ in [] }
        let gate = DelayGate()
        let clock = FixedTimeSource(now: now)
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher, timeSource: clock, sleep: { try await gate.sleep($0) })
        let fetch = Task { await reader.refresh(minInterval: 0) }
        try await waitFor { await gate.contains(15) }
        await gate.release(15)
        await fetch.value
        #expect(launcher.terminationCount == 1)
        launcher.emit(Data(#"{"method":"account/rateLimits/updated","params":{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":300}}}}"#.utf8))
        await reader.refresh(minInterval: 0)
        #expect(launcher.launchCount == 1)
        #expect(await reader.latest == nil)
        clock.advance(by: 120)
        // 가짜 프로세스 스트림은 종료되어 있으므로 재실행은 즉시 EOF로 실패한다.
        await reader.refresh(minInterval: 0)
        #expect(launcher.launchCount == 2)
        await reader.stop()
    }

    @Test func stopResolvesPendingRequest() async throws {
        let launcher = ScriptedProcessLauncher { _ in [] }
        let gate = DelayGate()
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher, sleep: { try await gate.sleep($0) })
        let fetch = Task { await reader.refresh(minInterval: 0) }
        try await waitFor { await gate.contains(15) }
        await reader.stop()
        await fetch.value
        #expect(launcher.terminationCount == 1)
        #expect(await reader.latest == nil)
    }

    @Test func failedSecondRequestRetainsSuccessAndIdleStops() async throws {
        let fail = Mutex(false)
        let launcher = ScriptedProcessLauncher { bytes in
            let message = JSONValue.parseObject(from: bytes)
            guard let id = message?["id"]?.intValue else { return [] }
            if message?["method"]?.stringValue == "initialize" { return [Data("{\"id\":\(id),\"result\":{}}\n".utf8)] }
            if fail.withLock({ $0 }) { return [Data("{\"id\":\(id),\"error\":{\"code\":-1}}\n".utf8)] }
            return [Data("{\"id\":\(id),\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":35,\"windowDurationMins\":300}}}}\n".utf8)]
        }
        let gate = DelayGate()
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher, sleep: { try await gate.sleep($0) })
        await reader.refresh(minInterval: 0)
        #expect(await reader.latest?.fiveHour?.usedRatio == 0.35)
        fail.withLock { $0 = true }
        await reader.refresh(minInterval: 0)
        #expect(await reader.latest?.fiveHour?.usedRatio == 0.35)
        #expect(launcher.terminationCount == 1)
        await reader.stop()
    }

    @Test func successfulQueryStopsAfterIdleDelay() async throws {
        let launcher = ScriptedProcessLauncher { bytes in
            guard let message = JSONValue.parseObject(from: bytes), let id = message["id"]?.intValue else { return [] }
            let result = message["method"]?.stringValue == "initialize" ? "{}" : #"{"rateLimits":{"secondary":{"usedPercent":25,"windowDurationMins":10080}}}"#
            return [Data("{\"id\":\(id),\"result\":\(result)}\n".utf8)]
        }
        let gate = DelayGate()
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher, sleep: { try await gate.sleep($0) })
        await reader.refresh(minInterval: 0)
        try await waitFor { await gate.contains(60) }
        await gate.release(60)
        try await waitFor { launcher.terminationCount == 1 }
        #expect(await reader.latest?.weekly?.usedRatio == 0.25)
    }

    @Test func desktopDiscoveryAndLatestWholeSnapshot() async throws {
        let files = InMemoryFileSystem()
        let cache = files.homeDirectory.appendingPathComponent("Library/Application Support/Claude/Cache/Cache_Data/abcd_0")
        var body = UsageTests().entry(body: Data(#"{"five_hour":{"utilization":70}}"#.utf8))
        body.append(Data(repeating: 32, count: 500 - body.count))
        files.addFile(at: cache, data: body, modifiedAt: now)
        let status = files.homeDirectory.appendingPathComponent(".ai-run/status/a.json")
        files.addFile(at: status, text: #"{"rate_limits":{"seven_day":{"used_percentage":20}}}"#, modifiedAt: now.addingTimeInterval(-1))
        let monitor = UsageMonitor(fileSystem: files, timeSource: FixedTimeSource(now: now))
        _ = await monitor.getUsages()
        try await waitFor { await monitor.getUsages().first?.fiveHour?.usedRatio == 0.7 }
        let reads = files.readCount(of: cache)
        _ = await monitor.getUsages()
        #expect(files.readCount(of: cache) == reads)
        files.setModifiedAt(now.addingTimeInterval(1), at: status)
        let selected = await monitor.getUsages().first
        #expect(selected?.weekly?.usedRatio == 0.2)
        #expect(selected?.fiveHour == nil)
        await monitor.stop()
    }
    @Test func cancellingRefreshStopsPendingProcess() async throws {
        let launcher = ScriptedProcessLauncher { _ in [] }
        let gate = DelayGate()
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher, sleep: { try await gate.sleep($0) })
        let fetch = Task { await reader.refresh(minInterval: 0) }
        try await waitFor { await gate.contains(15) }
        fetch.cancel()
        await fetch.value
        try await waitFor { launcher.terminationCount == 1 }
        #expect(await reader.latest == nil)
    }

    @Test func missingBinaryWaitsTenMinutes() async throws {
        let files = InMemoryFileSystem()
        let clock = FixedTimeSource(now: now)
        let launcher = ScriptedProcessLauncher { _ in [] }
        let reader = CodexRateLimitReader(fileSystem: files, launcher: launcher, timeSource: clock)
        await reader.refresh(minInterval: 0)
        files.addFile(at: files.homeDirectory.appendingPathComponent(".local/bin/codex"), text: "", modifiedAt: now)
        clock.advance(by: 599)
        await reader.refresh(minInterval: 0)
        #expect(launcher.launchCount == 0)
        clock.advance(by: 1)
        let fetch = Task { await reader.refresh(minInterval: 0) }
        try await waitFor { launcher.launchCount == 1 }
        await reader.stop()
        await fetch.value
    }

    @Test func livePipeStreamsAndCloses() async throws {
        let child = try SystemProcessLauncher().launch(executable: URL(fileURLWithPath: "/bin/cat"), arguments: [], environment: [:])
        defer { child.terminate() }
        try child.write(Data("synthetic-only\n".utf8))
        var iterator = child.output.makeAsyncIterator()
        let bytes = await iterator.next()
        #expect(bytes == Data("synthetic-only\n".utf8))
        child.terminate()
        #expect(await iterator.next() == nil)
        #expect(throws: (any Error).self) { try child.write(Data([1])) }
    }

    @Test func waitingUpdateCallbackDoesNotBlockRPCOrNotifications() async throws {
        let launcher = ScriptedProcessLauncher { bytes in
            guard let message = JSONValue.parseObject(from: bytes), let id = message["id"]?.intValue else { return [] }
            let result = message["method"]?.stringValue == "initialize" ? "{}" : #"{"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":300}}}"#
            return [Data("{\"id\":\(id),\"result\":\(result)}\n".utf8)]
        }
        let gate = DelayGate()
        let callbacks = Mutex(0)
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher, onUpdate: {
            let first = callbacks.withLock { count in count += 1; return count == 1 }
            if first { try? await gate.sleep(999) }
        })
        let fetch = Task { await reader.refresh(minInterval: 0) }
        do {
            try await waitFor { await gate.contains(999) }
            let notification = #"{"method":"account/rateLimits/updated","params":{"rateLimits":{"primary":{"usedPercent":60,"windowDurationMins":300}}}}"#
            launcher.emit(Data((notification + "\n").utf8))
            try await waitFor { await reader.latest?.fiveHour?.usedRatio == 0.6 }
            await reader.refresh(minInterval: 0)
            #expect(await reader.latest?.fiveHour?.usedRatio == 0.1)
        } catch {
            await gate.release(999)
            await reader.stop()
            await fetch.value
            throw error
        }
        await gate.release(999)
        await fetch.value
        await reader.stop()
    }

    @Test func primitiveInitializeResultIsRejected() async {
        let launcher = ScriptedProcessLauncher { bytes in
            guard let id = JSONValue.parseObject(from: bytes)?["id"]?.intValue else { return [] }
            return [Data("{\"id\":\(id),\"result\":true}\n".utf8)]
        }
        let reader = CodexRateLimitReader(fileSystem: files(), launcher: launcher)
        await reader.refresh(minInterval: 0)
        #expect(launcher.writes.count == 1)
        #expect(launcher.terminationCount == 1)
        #expect(await reader.latest == nil)
    }

}
