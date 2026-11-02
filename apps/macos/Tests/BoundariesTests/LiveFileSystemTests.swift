import Foundation
import Testing
@testable import Boundaries

/// 실제 ~/.claude 등은 읽지 않고 임시 폴더에서만 확인한다.
private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("desktoto-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

@Test func liveFileSystemListsOnlyVisibleFilesWithExtension() throws {
    try withTemporaryDirectory { directory in
        let nested = directory.appendingPathComponent("a/b")
        let hidden = directory.appendingPathComponent(".hidden")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
        try Data("{}\n".utf8).write(to: nested.appendingPathComponent("one.jsonl"))
        try Data("{}\n".utf8).write(to: directory.appendingPathComponent("two.jsonl"))
        try Data("{}\n".utf8).write(to: directory.appendingPathComponent(".three.jsonl"))
        try Data("{}\n".utf8).write(to: hidden.appendingPathComponent("four.jsonl"))
        try Data("x".utf8).write(to: directory.appendingPathComponent("five.txt"))

        let names = LiveFileSystem(homeDirectory: directory)
            .listFiles(under: directory, withExtension: "jsonl")
            .map(\.url.lastPathComponent)
            .sorted()

        #expect(names == ["one.jsonl", "two.jsonl"])
    }
}

@Test func liveFileSystemReadsTailHeadAndWholeFile() throws {
    try withTemporaryDirectory { directory in
        let url = directory.appendingPathComponent("log.jsonl")
        try Data("0123456789".utf8).write(to: url)
        let fileSystem = LiveFileSystem(homeDirectory: directory)

        #expect(fileSystem.readTail(of: url, maxBytes: 4) == FileTail(data: Data("6789".utf8), isStartTruncated: true))
        #expect(fileSystem.readTail(of: url, maxBytes: 100) == FileTail(data: Data("0123456789".utf8), isStartTruncated: false))
        #expect(fileSystem.readHead(of: url, maxBytes: 3) == Data("012".utf8))
        #expect(fileSystem.readAll(of: url) == Data("0123456789".utf8))
        #expect(fileSystem.modificationDate(of: url) != nil)
        #expect(fileSystem.creationDate(of: url) != nil)
    }
}

@Test func liveFileSystemReturnsNilForMissingFile() {
    let missing = URL(fileURLWithPath: "/nonexistent-desktoto-test/none.jsonl")
    let fileSystem = LiveFileSystem(homeDirectory: URL(fileURLWithPath: "/nonexistent-desktoto-test"))

    #expect(fileSystem.readTail(of: missing, maxBytes: 10) == nil)
    #expect(fileSystem.readHead(of: missing, maxBytes: 10) == nil)
    #expect(fileSystem.readAll(of: missing) == nil)
    #expect(fileSystem.modificationDate(of: missing) == nil)
    #expect(fileSystem.listFiles(under: missing, withExtension: "jsonl").isEmpty)
}
