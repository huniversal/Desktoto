import Boundaries
import Domain
import Foundation
import Synchronization

/// Claude 데스크탑 앱은 세션마다 메타데이터 파일에 앱용 id(`sessionId`: local_…)와 기록 파일 id(`cliSessionId`)를 함께 저장한다.
/// 이 연결로 기록 파일의 세션을 앱의 딥링크로 열 수 있다. 앱 내부 형식이라 못 찾으면 nil이다.
public final class ClaudeDesktopSessionLinks: SessionLinkResolver {
    private static let refreshInterval: TimeInterval = 10
    private static let metadataRelativePath = "Library/Application Support/Claude/claude-code-sessions"

    private struct Cache {
        var desktopSessionIDs: [String: String] = [:]
        var loadedAt = Date.distantPast
    }

    private let fileSystem: any FileSystem
    private let timeSource: any TimeSource
    private let cache = Mutex(Cache())

    public init(fileSystem: any FileSystem, timeSource: any TimeSource) {
        self.fileSystem = fileSystem
        self.timeSource = timeSource
    }

    public func url(forSessionID sessionID: String) -> URL? {
        let now = timeSource.now
        let isStale = cache.withLock { $0.desktopSessionIDs[sessionID] == nil && now.timeIntervalSince($0.loadedAt) > Self.refreshInterval }
        if isStale {
            let map = loadDesktopSessionIDs()
            cache.withLock {
                $0.desktopSessionIDs = map
                $0.loadedAt = now
            }
        }
        return cache.withLock { $0.desktopSessionIDs[sessionID] }.flatMap { URL(string: "claude://claude.ai/epitaxy/\($0)") }
    }

    private func loadDesktopSessionIDs() -> [String: String] {
        let root = fileSystem.homeDirectory.appendingPathComponent(Self.metadataRelativePath)
        var map: [String: String] = [:]
        for entry in fileSystem.listFiles(under: root, withExtension: "json") {
            guard let data = fileSystem.readAll(of: entry.url),
                  let json = JSONValue.parseObject(from: data),
                  let cliSessionID = json["cliSessionId"]?.stringValue,
                  let desktopSessionID = json["sessionId"]?.stringValue else { continue }
            map[cliSessionID] = desktopSessionID
        }
        return map
    }
}
