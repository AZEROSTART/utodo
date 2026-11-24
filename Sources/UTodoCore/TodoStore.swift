import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class TodoStore: @unchecked Sendable {
    public static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment["UTODO_DB"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "utodo", directoryHint: .isDirectory)
            .appending(path: "utodo.sqlite3", directoryHint: .notDirectory)
    }

    private let url: URL
    private var db: OpaquePointer?
    private let lock = NSLock()

    public init(url: URL = TodoStore.defaultURL) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var handle = try Self.open(at: url)
        do {
            try Self.prepareSchema(handle)
        } catch {
            sqlite3_close(handle)
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            handle = try Self.open(at: url)
            try Self.prepareSchema(handle)
        }
        db = handle
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - 写入

    @discardableResult
    public func add(title: String) throws -> Todo? {
        try add(titles: [title]).first
    }

    @discardableResult
    public func add(titles: [String]) throws -> [Todo] {
        let cleaned = titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return [] }

        let base = Date()
        let total = cleaned.count
        let now = cleaned.enumerated().map { index, title in
            Todo(
                id: UUID(),
                title: title,
                createdAt: base.addingTimeInterval(Double(total - index) * 0.001),
                completedAt: nil
            )
        }

        lock.lock()
        defer { lock.unlock() }
        let db = try database()
        try exec(db, "BEGIN IMMEDIATE")
        do {
            for todo in now {
                let stmt = try prepare(
                    db,
                    "INSERT INTO todos (id, title, created_at, completed_at) VALUES (?, ?, ?, NULL)"
                )
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_text(stmt, 1, todo.id.uuidString.lowercased(), -1, sqliteTransient)
                sqlite3_bind_text(stmt, 2, todo.title, -1, sqliteTransient)
                sqlite3_bind_double(stmt, 3, todo.createdAt.timeIntervalSinceReferenceDate)
                try stepDone(db, stmt)
            }
            try exec(db, "COMMIT")
        } catch {
            try? exec(db, "ROLLBACK")
            throw error
        }
        return now
    }

    @discardableResult
    public func complete(idPrefix: String) throws -> Todo {
        lock.lock()
        defer { lock.unlock() }
        let todo = try resolveLocked(prefix: idPrefix)
        guard todo.completedAt == nil else { return todo }

        let db = try database()
        let stmt = try prepare(db, "UPDATE todos SET completed_at = ? WHERE id = ?")
        defer { sqlite3_finalize(stmt) }
        let now = Date()
        sqlite3_bind_double(stmt, 1, now.timeIntervalSinceReferenceDate)
        sqlite3_bind_text(stmt, 2, todo.id.uuidString.lowercased(), -1, sqliteTransient)
        try stepDone(db, stmt)

        return Todo(id: todo.id, title: todo.title, createdAt: todo.createdAt, completedAt: now)
    }

    @discardableResult
    public func delete(idPrefix: String) throws -> Todo {
        lock.lock()
        defer { lock.unlock() }
        let todo = try resolveLocked(prefix: idPrefix)
        let db = try database()
        let stmt = try prepare(db, "DELETE FROM todos WHERE id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, todo.id.uuidString.lowercased(), -1, sqliteTransient)
        try stepDone(db, stmt)
        return todo
    }

    @discardableResult
    public func clearCompleted() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let db = try database()
        try exec(db, "DELETE FROM todos WHERE completed_at IS NOT NULL")
        return Int(sqlite3_changes(db))
    }

    // MARK: - 读取

    public func list(includeCompleted: Bool) throws -> [Todo] {
        lock.lock()
        defer { lock.unlock() }
        let db = try database()
        let sql = includeCompleted
            ? """
              SELECT id, title, created_at, completed_at FROM todos
              ORDER BY (completed_at IS NOT NULL),
                       CASE WHEN completed_at IS NULL THEN created_at ELSE completed_at END DESC
              """
            : "SELECT id, title, created_at, completed_at FROM todos WHERE completed_at IS NULL ORDER BY created_at DESC"
        let stmt = try prepare(db, sql)
        defer { sqlite3_finalize(stmt) }

        var todos: [Todo] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let rawID = sqlite3_column_text(stmt, 0),
                  let rawTitle = sqlite3_column_text(stmt, 1),
                  let id = UUID(uuidString: String(cString: rawID))
            else { continue }
            let createdAt = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 2))
            let completedAt: Date? = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 3))
            todos.append(Todo(
                id: id,
                title: String(cString: rawTitle),
                createdAt: createdAt,
                completedAt: completedAt
            ))
        }
        return todos
    }

    // MARK: - 内部

    private func resolveLocked(prefix: String) throws -> Todo {
        let needle = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
        guard !needle.isEmpty else { throw TodoStoreError.notFound }

        let db = try database()
        let stmt = try prepare(
            db,
            """
            SELECT id, title, created_at, completed_at FROM todos
            WHERE lower(replace(id, '-', '')) LIKE ? || '%'
            """
        )
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, needle, -1, sqliteTransient)

        var matches: [Todo] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let rawID = sqlite3_column_text(stmt, 0),
                  let rawTitle = sqlite3_column_text(stmt, 1),
                  let id = UUID(uuidString: String(cString: rawID))
            else { continue }
            let completedAt: Date? = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 3))
            matches.append(Todo(
                id: id,
                title: String(cString: rawTitle),
                createdAt: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 2)),
                completedAt: completedAt
            ))
        }

        switch matches.count {
        case 0: throw TodoStoreError.notFound
        case 1: return matches[0]
        default: throw TodoStoreError.ambiguousPrefix
        }
    }

    private func database() throws -> OpaquePointer {
        guard let db else { throw TodoStoreError.database("数据库未打开") }
        return db
    }

    private static func open(at url: URL) throws -> OpaquePointer {
        var handle: OpaquePointer?
        let rc = sqlite3_open(url.path, &handle)
        guard rc == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open 失败"
            if let handle { sqlite3_close(handle) }
            throw TodoStoreError.database(message)
        }
        sqlite3_busy_timeout(handle, 2000)
        return handle
    }

    private static func prepareSchema(_ db: OpaquePointer) throws {
        var mode: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA journal_mode=WAL", -1, &mode, nil) == SQLITE_OK,
              sqlite3_step(mode) == SQLITE_ROW
        else {
            sqlite3_finalize(mode)
            throw TodoStoreError.database(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_finalize(mode)

        guard sqlite3_exec(
            db,
            """
            CREATE TABLE IF NOT EXISTS todos (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                completed_at REAL
            )
            """,
            nil, nil, nil
        ) == SQLITE_OK else {
            throw TodoStoreError.database(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func prepare(_ db: OpaquePointer, _ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw TodoStoreError.database(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    private func exec(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw TodoStoreError.database(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func stepDone(_ db: OpaquePointer, _ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TodoStoreError.database(String(cString: sqlite3_errmsg(db)))
        }
    }
}
