import Foundation
import UTodoCore

let arguments = Array(CommandLine.arguments.dropFirst())
let version = "0.1.0"

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func usage() -> Never {
    fail(
        """
        用法：
          utodo add <标题>            新增一条；`utodo add -` 从 stdin 读多行
          utodo list [--json]         列出未完成
          utodo done <短id前缀>       标记完成
          utodo rm <短id前缀>         删除
          utodo clear                 清除全部已完成
          utodo --version             版本号
        """,
        code: 2
    )
}

func shortID(_ todo: Todo) -> String {
    String(todo.id.uuidString.prefix(8)).lowercased()
}

struct TodoJSON: Encodable {
    let id: String
    let title: String
    let created_at: String
    let completed_at: String?
}

func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func encodeJSON(_ todos: [Todo]) throws -> String {
    let payload = todos.map {
        TodoJSON(
            id: $0.id.uuidString.lowercased(),
            title: $0.title,
            created_at: iso8601($0.createdAt),
            completed_at: $0.completedAt.map(iso8601)
        )
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)
    return String(decoding: data, as: UTF8.self)
}

func readStdin() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

func describe(_ error: Error) -> (String, Int32) {
    switch error {
    case TodoStoreError.notFound: return ("找不到该事项", 1)
    case TodoStoreError.ambiguousPrefix: return ("短 id 前缀匹配到多条，请写长一点", 1)
    case let TodoStoreError.database(message): return ("数据库错误：\(message)", 1)
    default: return ("\(error)", 1)
    }
}

let store: TodoStore
do {
    store = try TodoStore()
} catch {
    let (message, code) = describe(error)
    fail(message, code: code)
}

guard let command = arguments.first else { usage() }
let rest = Array(arguments.dropFirst())

do {
    switch command {
    case "add":
        guard !rest.isEmpty else { usage() }
        let raw = rest == ["-"] ? readStdin() : rest.joined(separator: " ")
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let added = try store.add(titles: lines)
        guard !added.isEmpty else { exit(0) }
        added.forEach { print("\(shortID($0))  \($0.title)") }
        postStoreChanged()

    case "list":
        let todos = try store.list(includeCompleted: false)
        if rest.contains("--json") {
            print(try encodeJSON(todos))
        } else {
            todos.forEach { print("\(shortID($0))  \($0.title)") }
        }

    case "done":
        guard let prefix = rest.first else { usage() }
        let todo = try store.complete(idPrefix: prefix)
        print("完成  \(shortID(todo))  \(todo.title)")
        postStoreChanged()

    case "rm":
        guard let prefix = rest.first else { usage() }
        let todo = try store.delete(idPrefix: prefix)
        print("删除  \(shortID(todo))  \(todo.title)")
        postStoreChanged()

    case "clear":
        let count = try store.clearCompleted()
        print("已清除 \(count) 条")
        postStoreChanged()

    case "--version":
        print("utodo \(version)")

    case "--help", "-h", "help":
        usage()

    default:
        fail("未知命令：\(command)", code: 2)
    }
} catch {
    let (message, code) = describe(error)
    fail(message, code: code)
}
