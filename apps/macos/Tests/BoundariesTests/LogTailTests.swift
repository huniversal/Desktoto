import Foundation
import Testing
import TestSupport
@testable import Boundaries

private let logURL = URL(fileURLWithPath: "/Users/test/.claude/projects/app/session.jsonl")
private let anyDate = Date(timeIntervalSince1970: 1_800_000_000)

private func makeFileSystem(contents: String) -> InMemoryFileSystem {
    let fileSystem = InMemoryFileSystem()
    fileSystem.addFile(at: logURL, text: contents, modifiedAt: anyDate)
    return fileSystem
}

private func ids(of records: [JSONValue]) -> [String] {
    records.compactMap { $0["id"]?.stringValue }
}

@Test func parseRecordsReturnsNewestFirst() {
    let data = Data(#"{"id":"a"}"#.utf8) + Data("\n".utf8) + Data(#"{"id":"b"}"#.utf8) + Data("\n".utf8) + Data(#"{"id":"c"}"#.utf8) + Data("\n".utf8)
    #expect(ids(of: LogTail.parseRecords(data, isStartTruncated: false)) == ["c", "b", "a"])
}

@Test func parseRecordsKeepsLastLineWithoutTrailingNewline() {
    let data = Data("{\"id\":\"a\"}\n{\"id\":\"b\"}".utf8)
    #expect(ids(of: LogTail.parseRecords(data, isStartTruncated: false)) == ["b", "a"])
}

@Test func parseRecordsSkipsBrokenBlankAndNonObjectLines() {
    let text = """
    {"id":"a"}
    not json
    [1,2,3]
    42

    {"id":"b"
    {"id":"c"}
    """
    #expect(ids(of: LogTail.parseRecords(Data(text.utf8), isStartTruncated: false)) == ["c", "a"])
}

@Test func parseRecordsDropsFirstLineWhenStartIsTruncated() {
    let data = Data("ial\":1}\n{\"id\":\"b\"}\n".utf8)
    #expect(ids(of: LogTail.parseRecords(data, isStartTruncated: true)) == ["b"])
}

@Test func parseRecordsKeepsFirstLineWhenStartIsNotTruncated() {
    let data = Data("{\"id\":\"a\"}\n{\"id\":\"b\"}\n".utf8)
    #expect(ids(of: LogTail.parseRecords(data, isStartTruncated: false)) == ["b", "a"])
}

@Test func readRecordsHandlesWindowStartingInsideMultibyteCharacter() {
    let first = "{\"id\":\"a\",\"text\":\"가나다라마\"}\n"
    let second = "{\"id\":\"b\",\"text\":\"바사\"}\n"
    let bytes = Data((first + second).utf8)
    let secondSize = Data(second.utf8).count
    // 첫 줄 한가운데(한글 3바이트 문자의 둘째 바이트)에서 읽기를 시작하게 맞춘다.
    let cutOffset = Data("{\"id\":\"a\",\"text\":\"가".utf8).count + 1
    let maxBytes = UInt64(bytes.count - cutOffset)
    #expect(maxBytes > UInt64(secondSize))

    let result = LogTail.readRecords(of: logURL, maxBytes: maxBytes, fileSystem: makeFileSystem(contents: first + second))

    #expect(ids(of: result.records) == ["b"])
    #expect(result.isComplete == false)
}

@Test func readRecordsReportsCompleteWhenWholeFileFitsInWindow() {
    let fileSystem = makeFileSystem(contents: "{\"id\":\"a\"}\n{\"id\":\"b\"}\n")

    let result = LogTail.readRecords(of: logURL, maxBytes: 1_000_000, fileSystem: fileSystem)

    #expect(ids(of: result.records) == ["b", "a"])
    #expect(result.isComplete)
}

@Test func readRecordsReturnsEmptyCompleteForEmptyOrMissingFile() {
    let emptyFileSystem = makeFileSystem(contents: "")
    let missing = URL(fileURLWithPath: "/Users/test/none.jsonl")

    #expect(LogTail.readRecords(of: logURL, maxBytes: 100, fileSystem: emptyFileSystem) == LogTailResult(records: [], isComplete: true))
    #expect(LogTail.readRecords(of: missing, maxBytes: 100, fileSystem: emptyFileSystem) == LogTailResult(records: [], isComplete: true))
}

@Test func readRecordsSkipsPartiallyWrittenLastLine() {
    let fileSystem = makeFileSystem(contents: "{\"id\":\"a\"}\n{\"id\":\"b\",\"te")

    let result = LogTail.readRecords(of: logURL, maxBytes: 1_000_000, fileSystem: fileSystem)

    #expect(ids(of: result.records) == ["a"])
}

@Test func jsonValueSeparatesBooleansFromNumbers() throws {
    let value = try #require(JSONValue.parseObject(from: Data(#"{"flag":true,"zero":0,"one":1,"ratio":1.5,"name":"x","none":null,"list":[1]}"#.utf8)))

    #expect(value["flag"] == .bool(true))
    #expect(value["zero"] == .number(0))
    #expect(value["one"]?.intValue == 1)
    #expect(value["ratio"]?.intValue == nil)
    #expect(value["name"]?.stringValue == "x")
    #expect(value["none"] == .null)
    #expect(value["list"]?.arrayValue == [.number(1)])
    #expect(value["missing"] == nil)
}

@Test func jsonValueRejectsNonObjects() {
    #expect(JSONValue.parseObject(from: Data("[1]".utf8)) == nil)
    #expect(JSONValue.parseObject(from: Data("oops".utf8)) == nil)
}
