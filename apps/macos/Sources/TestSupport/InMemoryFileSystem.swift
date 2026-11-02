import Boundaries
import Foundation
import Synchronization

/// 메모리에 파일을 두는 가짜 파일 시스템. 읽기 횟수를 세어 캐시 재사용을 확인할 수 있다.
public final class InMemoryFileSystem: FileSystem {
    private struct StoredFile {
        var data: Data
        var modifiedAt: Date
        var createdAt: Date
    }

    private struct State {
        var files: [String: StoredFile] = [:]
        var readCounts: [String: Int] = [:]
    }

    public let homeDirectory: URL
    private let state = Mutex(State())

    public init(homeDirectory: URL = URL(fileURLWithPath: "/Users/test")) {
        self.homeDirectory = homeDirectory
    }

    /// 파일을 만들거나 덮어쓴다. createdAt을 생략하면 modifiedAt과 같다.
    public func addFile(at url: URL, data: Data, modifiedAt: Date, createdAt: Date? = nil) {
        state.withLock {
            $0.files[url.path] = StoredFile(data: data, modifiedAt: modifiedAt, createdAt: createdAt ?? modifiedAt)
        }
    }

    public func addFile(at url: URL, text: String, modifiedAt: Date, createdAt: Date? = nil) {
        addFile(at: url, data: Data(text.utf8), modifiedAt: modifiedAt, createdAt: createdAt)
    }

    /// 내용은 그대로 두고 수정 시각만 바꾼다.
    public func setModifiedAt(_ modifiedAt: Date, at url: URL) {
        state.withLock { $0.files[url.path]?.modifiedAt = modifiedAt }
    }

    /// 파일의 내용을 읽은 횟수(끝부분, 앞부분, 전체 읽기의 합)
    public func readCount(of url: URL) -> Int {
        state.withLock { $0.readCounts[url.path] ?? 0 }
    }

    public func listFiles(under root: URL, withExtension pathExtension: String) -> [FileEntry] {
        let prefix = "\(root.path)/"
        return state.withLock { state in
            state.files.compactMap { path, file in
                guard path.hasPrefix(prefix) else { return nil }
                let components = path.dropFirst(prefix.count).split(separator: "/")
                guard !components.contains(where: { $0.hasPrefix(".") }) else { return nil }
                let url = URL(fileURLWithPath: path)
                guard url.pathExtension == pathExtension else { return nil }
                return FileEntry(url: url, modifiedAt: file.modifiedAt)
            }
        }
    }

    public func readTail(of url: URL, maxBytes: UInt64) -> FileTail? {
        readContents(of: url) { data in
            let readSize = min(UInt64(data.count), maxBytes)
            return FileTail(data: Data(data.suffix(Int(readSize))), isStartTruncated: readSize < UInt64(data.count))
        }
    }

    public func readHead(of url: URL, maxBytes: Int) -> Data? {
        readContents(of: url) { Data($0.prefix(maxBytes)) }
    }

    public func readAll(of url: URL) -> Data? {
        readContents(of: url) { $0 }
    }

    public func modificationDate(of url: URL) -> Date? {
        state.withLock { $0.files[url.path]?.modifiedAt }
    }

    public func creationDate(of url: URL) -> Date? {
        state.withLock { $0.files[url.path]?.createdAt }
    }

    private func readContents<Result>(of url: URL, transform: (Data) -> Result) -> Result? {
        state.withLock { state in
            guard let file = state.files[url.path] else { return nil }
            state.readCounts[url.path, default: 0] += 1
            return transform(file.data)
        }
    }
}
