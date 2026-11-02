import AppKit

public protocol URLOpener: Sendable {
    func open(_ url: URL) -> Bool
    func isRunning(bundleIdentifier: String) -> Bool
    func activate(bundleIdentifier: String)
}

public struct SystemURLOpener: URLOpener {
    public init() {}

    public func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    public func isRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    public func activate(bundleIdentifier: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.activate()
    }
}
