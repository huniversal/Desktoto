import Boundaries
import Foundation

public struct AvailableUpdate: Equatable, Sendable {
    public let release: LatestRelease
    public let installMethod: InstallMethod

    public init(release: LatestRelease, installMethod: InstallMethod) {
        self.release = release
        self.installMethod = installMethod
    }
}

// 새 버전이 있는지 24시간에 한 번만 묻고 결과를 보관한다. 실패는 모두 "새로 알릴 것 없음"으로 보고 다음 주기까지 다시 묻지 않는다.
public actor UpdateChecker {
    public static let checkInterval: TimeInterval = 24 * 60 * 60

    private let currentVersion: AppVersion
    private let installMethod: InstallMethod
    private let fetcher: any ReleaseFetching
    private let timeSource: any TimeSource
    private var lastCheckedAt: Date?
    private var isChecking = false
    private var availableUpdate: AvailableUpdate?

    public init(
        currentVersion: AppVersion,
        installMethod: InstallMethod,
        fetcher: any ReleaseFetching,
        timeSource: any TimeSource = SystemTimeSource()
    ) {
        self.currentVersion = currentVersion
        self.installMethod = installMethod
        self.fetcher = fetcher
        self.timeSource = timeSource
    }

    // 확인할 때가 되었으면 묻고, 지금 보여 줄 안내를 돌려준다. 꺼져 있으면 요청하지 않고 안내도 없다.
    // 이미 묻는 중이거나 아직 주기가 되지 않았으면 마지막 결과를 그대로 돌려준다. 실패해도 이전에 찾은 안내는 유지한다.
    public func refresh(isEnabled: Bool) async -> AvailableUpdate? {
        guard isEnabled else { return nil }
        guard !isChecking, isDue else { return availableUpdate }
        isChecking = true
        defer { isChecking = false }
        let startedAt = timeSource.now
        do {
            let release = try await fetcher.fetchLatest()
            availableUpdate = release.flatMap { latest in
                latest.version > currentVersion ? AvailableUpdate(release: latest, installMethod: installMethod) : nil
            }
        } catch {
            // 오프라인, 요청 제한, 형식 오류는 앱 동작에 영향을 주지 않는다.
        }
        lastCheckedAt = startedAt
        return availableUpdate
    }

    private var isDue: Bool {
        guard let lastCheckedAt else { return true }
        return timeSource.now.timeIntervalSince(lastCheckedAt) >= Self.checkInterval
    }
}
