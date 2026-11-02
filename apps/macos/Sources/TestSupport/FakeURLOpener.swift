import Boundaries
import Foundation
import Synchronization

// 실행 중인 앱 목록을 정해 두고 열기와 활성화 요청을 기록하는 가짜 URLOpener.
public final class FakeURLOpener: URLOpener {
    private struct State {
        var openedURLs: [URL] = []
        var activatedBundleIdentifiers: [String] = []
    }

    private let runningBundleIdentifiers: Set<String>
    private let state = Mutex(State())

    public init(runningBundleIdentifiers: Set<String> = []) {
        self.runningBundleIdentifiers = runningBundleIdentifiers
    }

    public var openedURLs: [URL] {
        state.withLock { $0.openedURLs }
    }

    public var activatedBundleIdentifiers: [String] {
        state.withLock { $0.activatedBundleIdentifiers }
    }

    public func open(_ url: URL) -> Bool {
        state.withLock { $0.openedURLs.append(url) }
        return true
    }

    public func isRunning(bundleIdentifier: String) -> Bool {
        runningBundleIdentifiers.contains(bundleIdentifier)
    }

    public func activate(bundleIdentifier: String) {
        state.withLock { $0.activatedBundleIdentifiers.append(bundleIdentifier) }
    }
}
