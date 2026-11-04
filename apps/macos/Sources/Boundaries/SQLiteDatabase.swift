import Foundation

public enum SQLiteValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    public var stringValue: String? {
        guard case .text(let value) = self else { return nil }
        return value
    }

    public var intValue: Int? {
        guard case .integer(let value) = self else { return nil }
        return Int(exactly: value)
    }
}

public typealias SQLiteRow = [String: SQLiteValue]

/// 다른 앱이 쓰는 SQLite 파일을 읽기만 하는 경계. 열 수 없거나 질의가 실패하면 nil을 돌려준다.
public protocol SQLiteDatabase: Sendable {
    /// sql은 SELECT 하나다. 값을 끼워 넣어야 하면 호출하는 쪽에서 신뢰할 수 있는 상수만 쓴다.
    func query(at url: URL, sql: String) -> [SQLiteRow]?
}
