import Foundation

public struct LogTailResult: Sendable, Equatable {
    /// 읽은 유효 기록(JSON 객체)을 최신순으로 나열한 것
    public let records: [JSONValue]
    /// 파일 처음까지 모두 읽었으면 true다. 범위를 더 넓혀도 새 기록이 나오지 않는다.
    public let isComplete: Bool

    public init(records: [JSONValue], isComplete: Bool) {
        self.records = records
        self.isComplete = isComplete
    }
}

/// 기록(.jsonl) 파일의 끝부분을 읽는 도구. 기록 끝에는 도구 결과처럼 수백 KB짜리 줄이 붙을 수 있어서, 읽는 크기를 호출하는 쪽이 정한다.
public enum LogTail {
    private static let newlineByte: UInt8 = 0x0A

    /// 파일 끝 maxBytes에서 읽은 유효 기록을 최신순으로 돌려준다. 파일을 읽지 못하면 기록 없이 완료로 돌려준다.
    public static func readRecords(of url: URL, maxBytes: UInt64, fileSystem: some FileSystem) -> LogTailResult {
        guard let tail = fileSystem.readTail(of: url, maxBytes: maxBytes) else {
            return LogTailResult(records: [], isComplete: true)
        }
        return LogTailResult(
            records: parseRecords(tail.data, isStartTruncated: tail.isStartTruncated),
            isComplete: !tail.isStartTruncated
        )
    }

    /// 줄 단위로 나눈 기록을 최신순으로 돌려준다.
    /// 읽기 시작 위치가 줄 중간(한글 같은 여러 바이트 문자의 중간일 수도 있다)이면 첫 줄을 버린다.
    /// 줄바꿈 바이트(0x0A)는 UTF-8 여러 바이트 문자 안에 나타나지 않으므로 바이트 단위로 나눠도 안전하다.
    /// 깨진 줄, 잘린 줄, 객체가 아닌 줄은 건너뛴다.
    public static func parseRecords(_ data: Data, isStartTruncated: Bool) -> [JSONValue] {
        var body = data
        if isStartTruncated, let newlineIndex = data.firstIndex(of: newlineByte) {
            body = data.suffix(from: data.index(after: newlineIndex))
        }
        return body
            .split(separator: newlineByte)
            .reversed()
            .compactMap { JSONValue.parseObject(from: Data($0)) }
    }
}
