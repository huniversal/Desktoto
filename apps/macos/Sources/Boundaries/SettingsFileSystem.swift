import Foundation

/// nil은 파일 없음, 접근 실패는 throw한다. 읽기 전용 FileSystem에는 쓰기 권한을 추가하지 않는다.
public protocol SettingsFileSystem: Sendable {
    var homeDirectory: URL { get }
    func resolvingSymlinks(at url: URL) -> URL
    func read(at url: URL) throws -> Data?
    func readPrefix(at url: URL, maxBytes: Int) throws -> Data?
    func directoryExists(at url: URL) -> Bool
    func writeAtomically(_ data: Data, to url: URL) throws
    /// 목적지가 있으면 덮어쓰지 않고 CocoaError.fileWriteFileExists를 던진다.
    func copyFile(at source: URL, to destination: URL) throws
}

public struct LiveSettingsFileSystem: SettingsFileSystem {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    public func resolvingSymlinks(at url: URL) -> URL { url.resolvingSymlinksInPath() }

    public func read(at url: URL) throws -> Data? {
        do { return try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
    }

    public func readPrefix(at url: URL, maxBytes: Int) throws -> Data? {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
        defer { try? handle.close() }
        return try handle.read(upToCount: maxBytes)
    }

    public func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    public func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func copyFile(at source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }
}
