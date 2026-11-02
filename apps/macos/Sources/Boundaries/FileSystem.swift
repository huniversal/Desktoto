import Foundation

public struct FileEntry: Sendable, Equatable {
    public let url: URL
    public let modifiedAt: Date

    public init(url: URL, modifiedAt: Date) {
        self.url = url
        self.modifiedAt = modifiedAt
    }
}

public struct FileTail: Sendable, Equatable {
    public let data: Data
    /// 파일 앞부분이 잘려서 data의 첫 줄이 중간부터 시작할 수 있으면 true다.
    public let isStartTruncated: Bool

    public init(data: Data, isStartTruncated: Bool) {
        self.data = data
        self.isStartTruncated = isStartTruncated
    }
}

/// 기록 파일을 읽는 데 필요한 동작만 굵게 정의한 파일 시스템 경계. 읽지 못하면 nil을 돌려준다.
public protocol FileSystem: Sendable {
    var homeDirectory: URL { get }

    /// root 아래의 파일을 하위 폴더까지 찾아 확장자가 맞는 것만 수정 시각과 함께 돌려준다. 숨김 파일과 숨김 폴더는 제외한다.
    func listFiles(under root: URL, withExtension pathExtension: String) -> [FileEntry]
    /// 파일 끝 maxBytes를 읽는다.
    func readTail(of url: URL, maxBytes: UInt64) -> FileTail?
    /// 파일 앞 maxBytes를 읽는다.
    func readHead(of url: URL, maxBytes: Int) -> Data?
    func readAll(of url: URL) -> Data?
    func modificationDate(of url: URL) -> Date?
    func creationDate(of url: URL) -> Date?
    /// 폴더가 있는지. 비어 있는 폴더와 없는 폴더를 구분해야 할 때 쓴다.
    func directoryExists(at url: URL) -> Bool
}
