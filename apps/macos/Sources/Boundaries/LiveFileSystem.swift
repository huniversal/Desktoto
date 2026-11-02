import Foundation

public struct LiveFileSystem: FileSystem {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    public func listFiles(under root: URL, withExtension pathExtension: String) -> [FileEntry] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var entries: [FileEntry] = []
        for case let url as URL in enumerator where url.pathExtension == pathExtension {
            guard let modifiedAt = modificationDate(of: url) else { continue }
            entries.append(FileEntry(url: url, modifiedAt: modifiedAt))
        }
        return entries
    }

    public func readTail(of url: URL, maxBytes: UInt64) -> FileTail? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let fileSize = try? handle.seekToEnd() else { return nil }
        let readSize = min(fileSize, maxBytes)
        guard (try? handle.seek(toOffset: fileSize - readSize)) != nil,
              let data = try? handle.readToEnd() else { return nil }
        return FileTail(data: data, isStartTruncated: readSize < fileSize)
    }

    public func readHead(of url: URL, maxBytes: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: maxBytes)
    }

    public func readAll(of url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    public func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    public func creationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    public func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
