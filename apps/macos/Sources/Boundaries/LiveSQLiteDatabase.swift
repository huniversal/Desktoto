import Foundation
import SQLite3

public struct LiveSQLiteDatabase: SQLiteDatabase {
    /// 다른 앱이 쓰는 중인 파일이라 오래 기다리지 않는다. 못 읽으면 다음 조회에서 다시 읽는다.
    private static let busyTimeoutMilliseconds: Int32 = 250

    public init() {}

    public func query(at url: URL, sql: String) -> [SQLiteRow]? {
        if let rows = run(path: url.path, flags: SQLITE_OPEN_READONLY, sql: sql) { return rows }
        return queryCopy(of: url, sql: sql)
    }

    /// WAL 모드 파일은 -wal과 -shm이 없으면 읽기 전용 연결로 열 수 없다. 원본은 건드리지 않고, 파일 묶음을 임시 폴더로 복사해 그 사본을 읽는다.
    /// 사본에는 대화 내용이 들어 있으므로 본인만 접근하는 폴더에 두고 읽은 직후 지운다.
    private func queryCopy(of url: URL, sql: String) -> [SQLiteRow]? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let directory = fileManager.temporaryDirectory.appendingPathComponent("desktoto-sqlite-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        } catch { return nil }
        defer { try? fileManager.removeItem(at: directory) }
        let copyPath = directory.appendingPathComponent(url.lastPathComponent).path
        for suffix in ["", "-wal", "-shm"] where fileManager.fileExists(atPath: url.path + suffix) {
            do { try fileManager.copyItem(atPath: url.path + suffix, toPath: copyPath + suffix) } catch { return nil }
        }
        // 사본이라 쓰기로 열어도 원본에는 영향이 없다. WAL을 복구하려면 쓰기 권한이 필요하다.
        return run(path: copyPath, flags: SQLITE_OPEN_READWRITE, sql: sql)
    }

    private func run(path: String, flags: Int32, sql: String) -> [SQLiteRow]? {
        var opened: OpaquePointer?
        let openCode = sqlite3_open_v2(path, &opened, flags, nil)
        defer { sqlite3_close(opened) }
        guard openCode == SQLITE_OK, let database = opened else { return nil }
        sqlite3_busy_timeout(database, Self.busyTimeoutMilliseconds)

        var prepared: OpaquePointer?
        let prepareCode = sqlite3_prepare_v2(database, sql, -1, &prepared, nil)
        defer { sqlite3_finalize(prepared) }
        guard prepareCode == SQLITE_OK, let statement = prepared else { return nil }

        var rows: [SQLiteRow] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: rows.append(readRow(statement))
            case SQLITE_DONE: return rows
            default: return nil
            }
        }
    }

    private func readRow(_ statement: OpaquePointer) -> SQLiteRow {
        var row: SQLiteRow = [:]
        for index in 0..<sqlite3_column_count(statement) {
            let name = String(cString: sqlite3_column_name(statement, index))
            switch sqlite3_column_type(statement, index) {
            case SQLITE_INTEGER:
                row[name] = .integer(sqlite3_column_int64(statement, index))
            case SQLITE_FLOAT:
                row[name] = .real(sqlite3_column_double(statement, index))
            case SQLITE_TEXT:
                row[name] = .text(sqlite3_column_text(statement, index).map { String(cString: $0) } ?? "")
            case SQLITE_BLOB:
                let count = Int(sqlite3_column_bytes(statement, index))
                row[name] = .blob(sqlite3_column_blob(statement, index).map { Data(bytes: $0, count: count) } ?? Data())
            default:
                row[name] = .null
            }
        }
        return row
    }
}
