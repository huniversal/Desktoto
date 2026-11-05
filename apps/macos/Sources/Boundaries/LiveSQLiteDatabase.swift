import Foundation
import SQLite3

public struct LiveSQLiteDatabase: SQLiteDatabase {
    /// 다른 앱이 쓰는 중인 파일이라 오래 기다리지 않는다. 못 읽으면 다음 조회에서 다시 읽는다.
    private static let busyTimeoutMilliseconds: Int32 = 250

    /// 읽기 전용으로 열 수 없을 때 사본을 만드는 폴더의 부모. 기본값은 시스템 임시 폴더다.
    private let stagingDirectory: URL

    public init(stagingDirectory: URL = FileManager.default.temporaryDirectory) {
        self.stagingDirectory = stagingDirectory
    }

    public func query(at url: URL, sql: String) -> [SQLiteRow]? {
        if let rows = run(path: url.path, flags: SQLITE_OPEN_READONLY, sql: sql) { return rows }
        return queryCopy(of: url, sql: sql)
    }

    /// WAL 모드 파일은 -wal과 -shm이 없으면 읽기 전용 연결로 열 수 없다. 원본은 건드리지 않고, 파일 묶음을 임시 폴더로 복사해 그 사본을 읽는다.
    /// 사본에는 대화 내용이 들어 있으므로 본인만 접근하는 폴더에 두고 읽은 직후 지운다.
    private func queryCopy(of url: URL, sql: String) -> [SQLiteRow]? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let directory = stagingDirectory.appendingPathComponent("desktoto-sqlite-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        } catch { return nil }
        defer { try? fileManager.removeItem(at: directory) }
        let copyPath = directory.appendingPathComponent(url.lastPathComponent).path
        let suffixes = ["", "-wal", "-shm"]
        let before = suffixes.map { modificationDate(atPath: url.path + $0) }
        for suffix in suffixes where fileManager.fileExists(atPath: url.path + suffix) {
            do { try fileManager.copyItem(atPath: url.path + suffix, toPath: copyPath + suffix) } catch { return nil }
        }
        // 복사하는 사이에 원본이 바뀌면(WAL이 비워지는 경우 등) 서로 다른 시점의 파일이 섞인 사본이 되므로 읽지 않는다.
        guard suffixes.map({ modificationDate(atPath: url.path + $0) }) == before else { return nil }
        // 사본이라 쓰기로 열어도 원본에는 영향이 없다. WAL을 복구하려면 쓰기 권한이 필요하다.
        return run(path: copyPath, flags: SQLITE_OPEN_READWRITE, sql: sql)
    }

    private func modificationDate(atPath path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
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
                row[name] = .text(sqlite3_column_text(statement, index).map { String(decoding: UnsafeBufferPointer(start: $0, count: Int(sqlite3_column_bytes(statement, index))), as: UTF8.self) } ?? "")
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
