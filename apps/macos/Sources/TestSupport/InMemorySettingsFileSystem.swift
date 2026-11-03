import Boundaries
import Foundation
import Synchronization

/// 설정 쓰기의 실패와 부작용을 검증하는 가짜 경계. 실제 사용자 경로에는 접근하지 않는다.
public final class InMemorySettingsFileSystem: SettingsFileSystem {
    public enum Operation: Sendable, Equatable {
        case read(URL)
        case prefix(URL, Int)
        case write(URL)
        case copy(URL, URL)
    }

    private struct State {
        var files: [URL: Data] = [:]
        var operations: [Operation] = []
    }

    public let homeDirectory: URL
    private let failReadAt: URL?
    private let failWriteAt: URL?
    private let failsCopy: Bool
    private let state = Mutex(State())

    public init(
        homeDirectory: URL = URL(fileURLWithPath: "/synthetic-home"),
        failReadAt: URL? = nil,
        failWriteAt: URL? = nil,
        failsCopy: Bool = false
    ) {
        self.homeDirectory = homeDirectory
        self.failReadAt = failReadAt
        self.failWriteAt = failWriteAt
        self.failsCopy = failsCopy
    }

    public var operations: [Operation] { state.withLock { $0.operations } }
    public var files: [URL: Data] { state.withLock { $0.files } }

    public func setFile(_ data: Data, at url: URL) { state.withLock { $0.files[url] = data } }
    public func resolvingSymlinks(at url: URL) -> URL { url }

    public func read(at url: URL) throws -> Data? {
        try state.withLock {
            $0.operations.append(.read(url))
            if url == failReadAt { throw CocoaError(.fileReadNoPermission) }
            return $0.files[url]
        }
    }

    public func readPrefix(at url: URL, maxBytes: Int) throws -> Data? {
        try state.withLock {
            $0.operations.append(.prefix(url, maxBytes))
            if url == failReadAt { throw CocoaError(.fileReadNoPermission) }
            return $0.files[url].map { Data($0.prefix(maxBytes)) }
        }
    }

    public func directoryExists(at url: URL) -> Bool {
        state.withLock { $0.files.keys.contains { $0.path.hasPrefix(url.path + "/") } }
    }

    public func writeAtomically(_ data: Data, to url: URL) throws {
        try state.withLock {
            $0.operations.append(.write(url))
            if url == failWriteAt { throw CocoaError(.fileWriteNoPermission) }
            $0.files[url] = data
        }
    }

    public func copyFile(at source: URL, to destination: URL) throws {
        try state.withLock {
            $0.operations.append(.copy(source, destination))
            if failsCopy { throw CocoaError(.fileWriteNoPermission) }
            if $0.files[destination] != nil { throw CocoaError(.fileWriteFileExists) }
            guard let data = $0.files[source] else { throw CocoaError(.fileReadNoSuchFile) }
            $0.files[destination] = data
        }
    }
}
