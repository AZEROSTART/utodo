import Foundation
import UTodoCore

let arguments = Array(CommandLine.arguments.dropFirst())
let version = "0.1.0"

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func helpText() -> String {
    """
    utodo \(version) — macOS 桌面右上角的玻璃待办卡

    用法：
      utodo                      打印这份帮助（装了 App 就直接用下面的命令）
      utodo add [--json] <标题>   新增一条；`utodo add -` 从 stdin 读多行，首行排最上
      utodo list [--json]        列出未完成
      utodo done <id前缀>        标记完成（8 位短 id，唯一前缀即可）
      utodo rm <id前缀>          删除
      utodo clear                清除全部已完成
      utodo config [--json]      查看透明度配置
      utodo config get <键>      读一个值
      utodo config set <键> <值>  改一个值，立即生效
      utodo agent install        让你的 AI 知道什么时候用 utodo（写 ~/AGENTS.md）
      utodo agent print          只打印要追加的那段说明
      utodo agent uninstall      撤销 agent install
      utodo --version            版本号
      utodo --help               这份帮助

    透明度两个键：
      glassOpacity  卡片玻璃底色         默认 0.3   范围 0…1       0 最透、1 最实
      dimAlpha      全屏时整窗 alpha     默认 0.55  范围 0.05…1    全屏 App 在前时变多淡
      短别名 glass / dim 都能用，例如：
        utodo config set glass 0.5      → glassOpacity: 0.3 → 0.5（立即上屏）
        utodo config set dim 0.35       → dimAlpha: 0.55 → 0.35

    退出码：0 成功 / 1 没找到或前缀有歧义 / 2 用法或取值错误
    配置：~/Library/Application Support/utodo/config.json
    """
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

// MARK: - 配置

/// 数字打印成最短的合理形式：0.30 → 0.3，0.05 → 0.05，1.0 → 1
func formatNumber(_ value: Double) -> String {
    var text = String(format: "%.2f", value)
    while text.contains("."), text.hasSuffix("0") || text.hasSuffix(".") {
        text.removeLast()
    }
    return text
}

struct ConfigKey {
    let name: String            // glassOpacity / dimAlpha
    let alias: String           // glass / dim
    let range: ClosedRange<Double>
    let summary: String
}

let configKeys: [ConfigKey] = [
    ConfigKey(
        name: "glassOpacity",
        alias: "glass",
        range: AppConfig.glassRange,
        summary: "卡片玻璃底色，0 最透、1 最实"
    ),
    ConfigKey(
        name: "dimAlpha",
        alias: "dim",
        range: AppConfig.dimRange,
        summary: "全屏时整窗 alpha，越小越淡"
    ),
]

func resolveConfigKey(_ raw: String) -> ConfigKey {
    let needle = raw.lowercased()
    if let key = configKeys.first(where: { $0.name.lowercased() == needle || $0.alias == needle }) {
        return key
    }
    fail(
        """
        未知的配置键：\(raw)
        可用键：\(configKeys.map { "\($0.alias)（\($0.name)）" }.joined(separator: "、"))
        例：utodo config set glass 0.5
        """,
        code: 2
    )
}

func configValue(_ key: ConfigKey, in config: AppConfig) -> Double {
    key.name == "glassOpacity" ? config.glassOpacity : config.dimAlpha
}

func integerBounds(_ key: ConfigKey) -> String {
    "\(formatNumber(key.range.lowerBound))…\(formatNumber(key.range.upperBound))"
}

func formatConfigJSON(_ config: AppConfig) -> String {
    // 手写而不是 JSONEncoder：键序固定、小数不丢精度，agent 好读
    """
    {"glassOpacity":\(formatNumber(config.glassOpacity)),"dimAlpha":\(formatNumber(config.dimAlpha))}
    """
}

func runConfig(_ args: [String]) {
    let store = ConfigStore()
    var json = false
    var rest: [String] = []
    for arg in args {
        if arg == "--json" {
            json = true
        } else if arg.hasPrefix("-") {
            fail("未知参数：\(arg)\n用法：utodo config [--json] | utodo config get <键> | utodo config set <键> <值>", code: 2)
        } else {
            rest.append(arg)
        }
    }

    switch (rest.first, rest.count) {
    case (nil, _):
        let config = store.load()
        if json {
            print(formatConfigJSON(config))
            exit(0)
        }
        for key in configKeys {
            let value = formatNumber(configValue(key, in: config))
            let name = (key.name + "=").padding(toLength: 13, withPad: " ", startingAt: 0)
            print("\(name)\(value)    # \(key.summary)；改：utodo config set \(key.alias) \(value)")
        }
        print("配置文件：\(ConfigStore.defaultURL.path)")

    case ("get", 2):
        let key = resolveConfigKey(rest[1])
        print(formatNumber(configValue(key, in: store.load())))

    case ("set", 3):
        let key = resolveConfigKey(rest[1])
        let old = configValue(key, in: store.load())
        guard let value = Double(rest[2]), value.isFinite else {
            fail("\(key.name) 需要数字，收到「\(rest[2])」\n例：utodo config set \(key.alias) 0.5", code: 2)
        }
        guard key.range.contains(value) else {
            fail(
                "\(key.name) 超出范围 \(integerBounds(key))，收到 \(formatNumber(value))；原值 \(formatNumber(old)) 未改",
                code: 2
            )
        }
        var config = store.load()
        if key.name == "glassOpacity" {
            config.glassOpacity = value
        } else {
            config.dimAlpha = value
        }
        do {
            try store.save(config)
        } catch {
            fail("写配置失败：\(error)\n路径：\(ConfigStore.defaultURL.path)", code: 1)
        }
        postConfigChanged()
        print("\(key.name): \(formatNumber(old)) → \(formatNumber(value))")

    case (let sub?, _):
        fail(
            """
            用法：
              utodo config                   查看当前值
              utodo config --json            机器可读
              utodo config get <键>          读一个值
              utodo config set <键> <值>     改一个值
            可用键：\(configKeys.map { "\($0.alias)（\($0.name)）" }.joined(separator: "、"))（收到「\(sub)」）
            """,
            code: 2
        )
    }
    exit(0)
}

// MARK: - agent

func runAgent(_ args: [String]) {
    let installer = AgentInstaller()
    let sub = args.first
    if sub == nil || sub == "install" {
        guard args.count <= 1 else {
            fail("用法：utodo agent install", code: 2)
        }
        do {
            let results = try installer.install()
            for result in results {
                let verb: String
                switch result.action {
                case .created: verb = "新建"
                case .updated: verb = "更新"
                case .unchanged: verb = "已是新内容"
                case .removed: verb = "删除"
                case .skipped: verb = "跳过"
                }
                let reason = result.reason.map { "（\($0)）" } ?? ""
                print("\(verb)  \(result.path)\(reason)")
            }
            print("")
            print("现在告诉你的 AI：用户说「记个待办」时用 utodo。")
            print("完整说明书：\(installer.skillFile.path)")
        } catch {
            fail("写入失败：\(error)", code: 1)
        }
        exit(0)
    }

    switch sub {
    case "print":
        guard args.count == 1 else { fail("用法：utodo agent print", code: 2) }
        print(installer.printBlock(), terminator: "")
        exit(0)

    case "uninstall":
        guard args.count == 1 else { fail("用法：utodo agent uninstall", code: 2) }
        do {
            let results = try installer.uninstall()
            for result in results {
                let verb: String
                switch result.action {
                case .removed: verb = result.path == installer.skillFile.path ? "删除" : "已移除说明"
                case .unchanged: verb = "本来就没有"
                case .skipped: verb = "跳过"
                default: verb = "更新"
                }
                let reason = result.reason.map { "（\($0)）" } ?? ""
                print("\(verb)  \(result.path)\(reason)")
            }
        } catch {
            fail("清理失败：\(error)", code: 1)
        }
        exit(0)

    default:
        fail("未知的 agent 子命令：\(sub!)\n用法：utodo agent install | print | uninstall", code: 2)
    }
}

// MARK: - 入口

guard let command = arguments.first else {
    print(helpText())
    exit(0)
}
let rest = Array(arguments.dropFirst())

switch command {
case "--version":
    print("utodo \(version)")
    exit(0)
case "--help", "-h", "help":
    print(helpText())
    exit(0)
case "config":
    runConfig(rest)
case "agent":
    runAgent(rest)
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
            fail("未知参数：\(arg)\n用法见 utodo --help", code: 2)
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
        guard !args.isEmpty else {
            fail("用法：utodo add [--json] <标题>（`utodo add -` 从 stdin 读多行）", code: 2)
        }
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
        guard parsed.rest.isEmpty else {
            fail("用法：utodo list [--json]", code: 2)
        }
        let todos = try store.list(includeCompleted: false)
        if parsed.json {
            print(try encodeJSON(todos, asArray: true))
        } else {
            todos.forEach { print("\(shortID($0))  \($0.title)") }
        }

    case "done":
        guard rest.count == 1, !rest[0].hasPrefix("-") else {
            fail("用法：utodo done <id前缀>", code: 2)
        }
        let todo = try store.complete(idPrefix: rest[0])
        print("完成  \(shortID(todo))  \(todo.title)")
        postStoreChanged()

    case "rm":
        guard rest.count == 1, !rest[0].hasPrefix("-") else {
            fail("用法：utodo rm <id前缀>", code: 2)
        }
        let todo = try store.delete(idPrefix: rest[0])
        print("删除  \(shortID(todo))  \(todo.title)")
        postStoreChanged()

    case "clear":
        guard rest.isEmpty else { fail("用法：utodo clear", code: 2) }
        let count = try store.clearCompleted()
        print("已清除 \(count) 条")
        postStoreChanged()

    default:
        fail("未知命令：\(command)\n跑 utodo --help 看全部命令", code: 2)
    }
} catch {
    let (message, code) = describe(error)
    fail(message, code: code)
}
