import Foundation
import TestSupport
import Testing
@testable import Boundaries

/// 실제 SQLite 파일을 임시 폴더에 만들어 확인한다. 사용자의 실제 Antigravity 파일은 읽지 않는다.
struct LiveSQLiteDatabaseTests {
    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("desktoto-sqlite-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func makeTable(at url: URL, usesWAL: Bool = false) throws -> SQLiteFixture {
        let fixture = try #require(SQLiteFixture(url: url, usesWAL: usesWAL))
        #expect(fixture.execute("CREATE TABLE items (id INTEGER, name TEXT, score REAL, note TEXT, payload BLOB)"))
        #expect(fixture.execute("INSERT INTO items VALUES (1, 'first', 1.5, NULL, x'0102'), (2, '둘째', 2.0, 'memo', NULL)"))
        return fixture
    }

    @Test func readsEveryColumnTypeInOrder() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("plain.db")
            let fixture = try makeTable(at: url)
            fixture.close()
            let rows = try #require(LiveSQLiteDatabase().query(at: url, sql: "SELECT * FROM items ORDER BY id"))
            #expect(rows.count == 2)
            #expect(rows[0]["id"] == .integer(1))
            #expect(rows[0]["name"] == .text("first"))
            #expect(rows[0]["score"] == .real(1.5))
            #expect(rows[0]["note"] == .null)
            #expect(rows[0]["payload"] == .blob(Data([1, 2])))
            #expect(rows[1]["name"]?.stringValue == "둘째")
            #expect(rows[1]["id"]?.intValue == 2)
        }
    }

    @Test func missingFileAndBrokenQueriesReturnNilWithoutCreatingFiles() throws {
        try withTemporaryDirectory { directory in
            let database = LiveSQLiteDatabase()
            let missing = directory.appendingPathComponent("missing.db")
            #expect(database.query(at: missing, sql: "SELECT 1") == nil)
            #expect(!FileManager.default.fileExists(atPath: missing.path))

            let url = directory.appendingPathComponent("plain.db")
            try makeTable(at: url).close()
            #expect(database.query(at: url, sql: "SELECT * FROM no_such_table") == nil)
            #expect(database.query(at: url, sql: "NOT SQL") == nil)

            let notDatabase = directory.appendingPathComponent("text.db")
            try Data("this is not a database file at all, just text".utf8).write(to: notDatabase)
            #expect(database.query(at: notDatabase, sql: "SELECT 1") == nil)
        }
    }

    @Test func readsDatabaseWhileAWriterKeepsWALFilesOpen() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("wal.db")
            let writer = try makeTable(at: url, usesWAL: true)
            // 쓰는 쪽 연결이 열려 있어 -wal과 -shm이 남아 있고, 마지막 변경은 아직 본 파일에 합쳐지지 않았을 수 있다.
            #expect(writer.execute("INSERT INTO items VALUES (3, 'third', 3.0, NULL, NULL)"))
            let rows = try #require(LiveSQLiteDatabase().query(at: url, sql: "SELECT id FROM items ORDER BY id"))
            #expect(rows.map { $0["id"]?.intValue } == [1, 2, 3])
            writer.close()
        }
    }

    @Test func readsWALDatabaseWhoseSidecarFilesAreGone() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("wal-closed.db")
            try makeTable(at: url, usesWAL: true).close()
            // 연결이 모두 닫히면 내용은 본 파일에 합쳐진다. -wal과 -shm이 없는 WAL 모드 파일은 읽기 전용으로 열 수 없어 사본으로 읽는 경우다.
            for suffix in ["-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
            let before = try Data(contentsOf: url)
            let rows = try #require(LiveSQLiteDatabase().query(at: url, sql: "SELECT count(*) AS n FROM items"))
            #expect(rows.first?["n"] == .integer(2))
            // 원본은 바뀌지 않고 옆에 새 파일도 생기지 않으며, 임시 사본도 남지 않는다.
            #expect(try Data(contentsOf: url) == before)
            #expect(FileManager.default.fileExists(atPath: url.path + "-wal") == false)
            #expect(FileManager.default.fileExists(atPath: url.path + "-shm") == false)
            let leftovers = try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)
                .filter { $0.hasPrefix("desktoto-sqlite-") && !$0.hasPrefix("desktoto-sqlite-tests-") }
            #expect(leftovers.isEmpty)
        }
    }
}
