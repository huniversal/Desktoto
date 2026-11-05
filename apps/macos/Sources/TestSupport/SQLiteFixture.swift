import Foundation
import SQLite3

/// 테스트가 실제 SQLite 파일을 만들고 고치는 도우미. 읽는 쪽 코드는 가짜 없이 진짜 파일로 확인한다.
public final class SQLiteFixture {
    private var handle: OpaquePointer?

    /// url에 파일을 만들어 쓰기 연결을 연다. usesWAL이면 WAL 모드로 바꾼다.
    public init?(url: URL, usesWAL: Bool = false) {
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return nil
        }
        if usesWAL, !execute("PRAGMA journal_mode=WAL") { return nil }
    }

    deinit { close() }

    /// 실행에 성공하면 true다.
    @discardableResult
    public func execute(_ sql: String) -> Bool {
        sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK
    }

    /// 연결을 닫는다. 마지막 연결이 닫히면 WAL 파일이 정리된다.
    public func close() {
        sqlite3_close(handle)
        handle = nil
    }
}
