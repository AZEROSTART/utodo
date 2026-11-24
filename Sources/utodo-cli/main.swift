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
          utodo add [--json] <标题>    新增一条；`utodo add -` 从 stdin 读多行
          utodo list [--json]           列出未完成
          utodo done <短id前缀>         标记完成
          utodo rm <短id前缀>           删除
          utodo clear                   清除全部已完成
          utodo --version               版本号
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

func encodeJSON(_ todos: [Todo], asArray: Bool) throws -> String {
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
    let data = asArray
        ? try encoder.encode(payload)
        : try encoder.encode(payload[0])
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

guard let command = arguments.first else { usage() }
let rest = Array(arguments.dropFirst())

// 不建库就能答的两条
switch command {
case "--version":
    print("utodo \(version)")
    exit(0)
case "--help", "-h", "help":
    usage()
default:
    break
}

/// 取出一个 `--json`，其余以 `-` 开头但不是 `-` 的参数视为用法错误
func splitFlags(_ args: [String], allowed: Set<String>) -> (json: Bool, rest: [String]) {
    var json = false
    var rest: [String] = []
    for arg in args {
        if arg == "--json", allowed.contains("json") {
            json = true
        } else if arg.hasPrefix("-"), arg != "-" {
            fail("未知参数：\(arg)", code: 2)
        } else {
            rest.append(arg)
        }
    }
    return (json, rest)
}

let store: TodoStore
do {
    store = try TodoStore()
} catch {
    let (message, code) = describe(error)
    fail(message, code: code)
}

do {
    switch command {
    case "add":
        let parsed = splitFlags(rest, allowed: ["json"])
        let args = parsed.rest
        guard !args.isEmpty else { usage() }
        let raw = args == ["-"] ? readStdin() : args.joined(separator: " ")
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let added = try store.add(titles: lines)
        guard !added.isEmpty else {
            if parsed.json { print("[]") }
            exit(0)
        }
        if parsed.json {
            print(try encodeJSON(added, asArray: added.count > 1))
        } else {
            added.forEach { print("\(shortID($0))  \($0.title)") }
        }
        postStoreChanged()

    case "list":
        let parsed = splitFlags(rest, allowed: ["json"])
        guard parsed.rest.isEmpty else { usage() }
        let todos = try store.list(includeCompleted: false)
        if parsed.json {
            print(try encodeJSON(todos, asArray: true))
        } else {
            todos.forEach { print("\(shortID($0))  \($0.title)") }
        }

    case "done":
        guard rest.count == 1, !rest[0].hasPrefix("-") else { usage() }
        let todo = try store.complete(idPrefix: rest[0])
        print("完成  \(shortID(todo))  \(todo.title)")
        postStoreChanged()

    case "rm":
        guard rest.count == 1, !rest[0].hasPrefix("-") else { usage() }
        let todo = try store.delete(idPrefix: rest[0])
        print("删除  \(shortID(todo))  \(todo.title)")
        postStoreChanged()

    case "clear":
        guard rest.isEmpty else { usage() }
        let count = try store.clearCompleted()
        print("已清除 \(count) 条")
        postStoreChanged()

    default:
        fail("未知命令：\(command)", code: 2)
    }
} catch {
    let (message, code) = describe(error)
    fail(message, code: code)
}
