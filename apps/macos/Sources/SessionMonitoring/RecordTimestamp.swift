import Boundaries
import Foundation

enum RecordTimestamp {
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle()

    /// 기록의 `timestamp`(ISO 8601)를 읽는다. 없거나 해석하지 못하면 nil이다.
    static func date(of record: JSONValue) -> Date? {
        guard let text = record["timestamp"]?.stringValue else { return nil }
        return (try? Date(text, strategy: withFraction)) ?? (try? Date(text, strategy: withoutFraction))
    }

    /// 시각이 없거나 읽을 수 없으면 fallback(파일 수정 시각)을 쓴다.
    static func date(of record: JSONValue, fallback: Date) -> Date {
        date(of: record) ?? fallback
    }
}
