import Foundation
import Synchronization
import TestSupport
import Testing
@testable import UpdateCheck

private struct OfflineError: Error {}

// 미리 정한 결과를 차례로 돌려주고 호출 횟수를 센다. delay가 있으면 그 동안 멈춰 있어 겹치는 호출을 만들 수 있다.
private final class ScriptedFetcher: ReleaseFetching {
    private let results: Mutex<[Result<LatestRelease?, Error>]>
    private let callCounter = Mutex(0)
    private let delay: Duration?

    init(_ results: [Result<LatestRelease?, Error>], delay: Duration? = nil) {
        self.results = Mutex(results)
        self.delay = delay
    }

    var callCount: Int { callCounter.withLock { $0 } }

    func fetchLatest() async throws -> LatestRelease? {
        callCounter.withLock { $0 += 1 }
        if let delay { try await Task.sleep(for: delay) }
        let next = results.withLock { $0.isEmpty ? Result<LatestRelease?, Error>.success(nil) : $0.removeFirst() }
        return try next.get()
    }
}

struct UpdateCheckerTests {
    private let current = AppVersion(major: 1, minor: 0, patch: 0)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func release(_ tag: String) -> LatestRelease {
        LatestRelease(tagName: tag)!
    }

    private func makeChecker(
        _ fetcher: ScriptedFetcher,
        time: FixedTimeSource,
        installMethod: InstallMethod = .manual
    ) -> UpdateChecker {
        UpdateChecker(currentVersion: current, installMethod: installMethod, fetcher: fetcher, timeSource: time)
    }

    // AC-3, AC-5
    @Test func reportsNewerReleaseWithInstallMethod() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0"))])
        let checker = makeChecker(fetcher, time: FixedTimeSource(now: start), installMethod: .homebrew)

        let update = await checker.refresh(isEnabled: true)

        #expect(update?.release.version == AppVersion(major: 1, minor: 1, patch: 0))
        #expect(update?.installMethod == .homebrew)
    }

    // AC-3
    @Test(arguments: ["v1.0.0", "v0.9.9"])
    func reportsNothingForSameOrOlderRelease(tag: String) async {
        let checker = makeChecker(ScriptedFetcher([.success(release(tag))]), time: FixedTimeSource(now: start))

        #expect(await checker.refresh(isEnabled: true) == nil)
    }

    // AC-3
    @Test func doesNotAskAgainBeforeTwentyFourHours() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0")), .success(release("v1.2.0"))])
        let time = FixedTimeSource(now: start)
        let checker = makeChecker(fetcher, time: time)

        _ = await checker.refresh(isEnabled: true)
        time.advance(by: UpdateChecker.checkInterval - 1)
        let update = await checker.refresh(isEnabled: true)

        #expect(fetcher.callCount == 1)
        #expect(update?.release.version == AppVersion(major: 1, minor: 1, patch: 0))
    }

    // AC-3
    @Test func asksAgainAfterTwentyFourHours() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0")), .success(release("v1.2.0"))])
        let time = FixedTimeSource(now: start)
        let checker = makeChecker(fetcher, time: time)

        _ = await checker.refresh(isEnabled: true)
        time.advance(by: UpdateChecker.checkInterval)
        let update = await checker.refresh(isEnabled: true)

        #expect(fetcher.callCount == 2)
        #expect(update?.release.version == AppVersion(major: 1, minor: 2, patch: 0))
    }

    // AC-3, AC-6
    @Test func neverAsksWhileDisabled() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0"))])
        let checker = makeChecker(fetcher, time: FixedTimeSource(now: start))

        #expect(await checker.refresh(isEnabled: false) == nil)
        #expect(fetcher.callCount == 0)
    }

    // AC-6
    @Test func hidesKnownUpdateWhileDisabledAndShowsItAgainWhenEnabled() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0"))])
        let checker = makeChecker(fetcher, time: FixedTimeSource(now: start))

        _ = await checker.refresh(isEnabled: true)

        #expect(await checker.refresh(isEnabled: false) == nil)
        #expect(await checker.refresh(isEnabled: true) != nil)
        #expect(fetcher.callCount == 1)
    }

    // AC-4
    @Test func treatsFailureAsNoUpdateAndWaitsForNextInterval() async {
        let fetcher = ScriptedFetcher([.failure(OfflineError()), .success(release("v1.1.0"))])
        let time = FixedTimeSource(now: start)
        let checker = makeChecker(fetcher, time: time)

        #expect(await checker.refresh(isEnabled: true) == nil)
        time.advance(by: 60)
        #expect(await checker.refresh(isEnabled: true) == nil)
        #expect(fetcher.callCount == 1)

        time.advance(by: UpdateChecker.checkInterval)
        #expect(await checker.refresh(isEnabled: true) != nil)
        #expect(fetcher.callCount == 2)
    }

    // AC-4
    @Test(arguments: [ReleaseFetchFailure.rateLimited, .unexpectedStatus(500), .invalidResponse])
    func treatsEveryFetchFailureAsNoUpdate(failure: ReleaseFetchFailure) async {
        let checker = makeChecker(ScriptedFetcher([.failure(failure)]), time: FixedTimeSource(now: start))

        #expect(await checker.refresh(isEnabled: true) == nil)
    }

    // AC-4
    @Test func treatsMissingReleaseAsNoUpdate() async {
        let checker = makeChecker(ScriptedFetcher([.success(nil)]), time: FixedTimeSource(now: start))

        #expect(await checker.refresh(isEnabled: true) == nil)
    }

    // AC-4
    @Test func keepsPreviouslyFoundUpdateWhenLaterCheckFails() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0")), .failure(OfflineError())])
        let time = FixedTimeSource(now: start)
        let checker = makeChecker(fetcher, time: time)

        _ = await checker.refresh(isEnabled: true)
        time.advance(by: UpdateChecker.checkInterval)

        #expect(await checker.refresh(isEnabled: true) != nil)
        #expect(fetcher.callCount == 2)
    }

    // AC-4
    @Test func doesNotStartOverlappingChecks() async {
        let fetcher = ScriptedFetcher([.success(release("v1.1.0"))], delay: .milliseconds(100))
        let checker = makeChecker(fetcher, time: FixedTimeSource(now: start))

        async let first = checker.refresh(isEnabled: true)
        async let second = checker.refresh(isEnabled: true)
        _ = await (first, second)

        #expect(fetcher.callCount == 1)
    }
}
