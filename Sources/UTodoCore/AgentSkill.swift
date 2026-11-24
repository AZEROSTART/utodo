import Foundation

/// 交给 agent 的说明书正文。仓库里的 `Skill/SKILL.md` 是同一份内容，
/// 测试会比对两者，防止改了文件忘了改二进制。
public enum AgentSkill {
    public static let beginMarker = "<!-- utodo:begin（由 `utodo agent install` 写入，勿手改） -->"
    public static let endMarker = "<!-- utodo:end -->"

    /// 追加到用户全局指令文件（AGENTS.md / CLAUDE.md）里的短说明
    public static let block = """
    \(beginMarker)
    ## 待办：utodo

    用户说「记个待办 / 帮我记一下 / 别忘了 X / 提醒我 X」时，用 `utodo` 记到桌面右上角的常驻卡片上，不要只在聊天里复述。

    - 记一条：`utodo add "18:30 前交季度报表"`
    - 记多条：`printf '甲\\n乙\\n' | utodo add -`（首行排最上）
    - 看未完成：`utodo list`；完成 / 删除：`utodo done <8位id>`、`utodo rm <8位id>`
    - 清除已完成：`utodo clear`
    - 调透明度：`utodo config`、`utodo config set glass 0.5`
    - 没装就先装：`git clone https://github.com/AZEROSTART/utodo.git && cd utodo && ./Scripts/install.sh`

    退出码 0 成功 / 1 没找到或前缀有歧义 / 2 用法错误。完整说明：`utodo --help` 或 `~/.local/share/utodo/SKILL.md`。
    \(endMarker)
    """

    /// 完整 SKILL.md（带 frontmatter），与仓库 `Skill/SKILL.md` 保持一致
    public static let text = """
    ---
    name: utodo
    description: 用户说「记个待办 / 帮我记一下 / 别忘了 X / 提醒我 X」时，用 utodo 把这件事写到 macOS 桌面右上角的常驻卡片上。也用于查看、完成、删除待办，以及调卡片透明度。
    ---

    # utodo

    utodo 是一张常驻 macOS 桌面右上角的玻璃待办卡。加一条后 1 秒内上屏，不弹通知、不抢焦点。你的任务是把用户口头交代的事**写进这张卡**，而不是只在对话里答应一下。

    ## 什么时候用

    - 用户说「记个待办」「帮我记一下」「别忘了」「提醒我」「回头要做」——只要是他自己要记的事，就 `utodo add`
    - 用户问「我还欠着什么 / 今天要做什么」——`utodo list`
    - 用户说「这个做完了 / 划掉 X」——`utodo done <id前缀>`
    - 用户说「删掉 X」——`utodo rm <id前缀>`

    不要用的情况：用户只是在讨论一个想法、让你查资料，或者确实需要到点响铃的提醒（那该用系统日历/提醒事项）。utodo 只存一行文字，不存日期和闹钟。

    ## 先确认装了没

    ```bash
    utodo --version    # 有输出就是装了
    ```

    没装（command not found）就装一次，装完重开终端：

    ```bash
    git clone https://github.com/AZEROSTART/utodo.git
    cd utodo && ./Scripts/install.sh
    ```

    装完 `utodo` 在 `~/.local/bin`，App 在 `~/Applications/UTodo.app`，并自动设为登录启动。

    ## 记一条

    ```bash
    utodo add "18:30 前交季度报表"
    ```

    - 标题就是卡片上显示的那一行，写清「做什么 + 什么时候」，不要写成长段落
    - 空标题会被忽略
    - 标题以 `-` 开头时走 stdin：`printf '%s\\n' "- 某事" | utodo add -`

    ## 记多条

    ```bash
    printf '甲\\n乙\\n丙\\n' | utodo add -
    ```

    首行排在卡片最上面（最新的在上）。

    ## 看、完成、删

    ```bash
    utodo list                 # 只列未完成，每行「8 位短 id + 两个空格 + 标题」
    utodo list --json          # 机器读：id / title / created_at
    utodo done 3f9a1c2b        # 完成；短 id 唯一前缀就行，写全 UUID 也可以
    utodo rm 3f9a1c2b          # 删除
    utodo clear                # 清除全部已完成
    ```

    短 id 是 UUID 前 8 位（小写）。前缀匹配到多条时会报错让你写长一点——那就多写几位。

    ## 调透明度

    卡片有两种透明度：玻璃底色，和「全屏 App 在前时变多淡」。

    ```bash
    utodo config                        # 当前值 + 改法，一行一个
    utodo config --json                 # {"glassOpacity":0.3,"dimAlpha":0.55}
    utodo config get glass              # 0.3
    utodo config set glass 0.5          # glassOpacity: 0.3 → 0.5，立即上屏
    utodo config set dim 0.35           # 全屏时保留更多存在感（默认 0.55）
    utodo config set glass 1.5          # 错：超出 0…1，退出 2，文件不动
    ```

    - `glass`（= `glassOpacity`）：卡片玻璃底色，`0` 最透、`1` 最实，默认 `0.3`
    - `dim`（= `dimAlpha`）：切到全屏 App 时整窗 alpha，默认 `0.55`，范围 `0.05…1`
    - 每次 `set` 都打印「旧值 → 新值」，不用再读一次
    - 改完立即生效，不用重启 App

    ## 退出码

    | 码 | 含义 |
    | --- | --- |
    | 0 | 成功（含 `--help`、`--version`） |
    | 1 | 没找到该 id，或前缀匹配到多条 |
    | 2 | 用法错误、参数不认、取值越界 |

    ## 常见坑

    - 卡片不弹系统通知：写完别跟用户说「我已提醒你」，说「已记到卡片上」
    - 卡片最多同时显示 5 条未完成，多了在卡内滚动；`list` 会列全部
    - 不要自己给标题加前缀（如 `[todo]`）；卡片本身已经说明它是待办
    - 数据库在 `~/Library/Application Support/utodo/utodo.sqlite3`，不要手改；要备份就整个目录一起备份
    """
}

public enum AgentInstallAction: String, Equatable {
    case created      // 文件原来不存在，新建
    case updated      // 内容有变化
    case unchanged    // 已经是目标内容
    case removed      // uninstall 删掉了文件/块
    case skipped      // 按规则没动（软链、与 AGENTS.md 同一文件、文件不存在）
}

public struct AgentInstallResult: Equatable {
    public let path: String
    public let action: AgentInstallAction
    public let reason: String?
}

/// 把 utodo 的用法写进用户的全局指令文件，让任意 agent 知道什么时候用它。
/// 所有写入都走「临时文件 + rename」，并且先解析符号链接 —— 用户可能把
/// `~/.claude/CLAUDE.md` 链到别处，原子替换会把软链本身换掉。
public struct AgentInstaller {
    private let home: URL
    private let skillText: String

    public init(home: URL = AgentInstaller.defaultHome, skillText: String = AgentSkill.text) {
        self.home = home
        self.skillText = skillText
    }

    public static var defaultHome: URL {
        if let override = ProcessInfo.processInfo.environment["HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public var agentsFile: URL { home.appending(path: "AGENTS.md") }
    public var claudeFile: URL { home.appending(path: ".claude/CLAUDE.md") }
    public var skillFile: URL { home.appending(path: ".local/share/utodo/SKILL.md") }

    public func printBlock() -> String { AgentSkill.block + "\n" }

    public func install() throws -> [AgentInstallResult] {
        var results: [AgentInstallResult] = []

        results.append(try writeBlock(to: agentsFile))

        if let skip = claudeSkipReason() {
            results.append(AgentInstallResult(path: claudeFile.path, action: .skipped, reason: skip))
        } else {
            results.append(try writeBlock(to: claudeFile))
        }

        results.append(try writeSkill())
        return results
    }

    public func uninstall() throws -> [AgentInstallResult] {
        var results: [AgentInstallResult] = []

        results.append(try removeBlock(from: agentsFile))
        if let skip = claudeSkipReason() {
            results.append(AgentInstallResult(path: claudeFile.path, action: .skipped, reason: skip))
        } else {
            results.append(try removeBlock(from: claudeFile))
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: skillFile.path) {
            try fileManager.removeItem(at: skillFile)
            results.append(AgentInstallResult(path: skillFile.path, action: .removed, reason: nil))
        } else {
            results.append(AgentInstallResult(path: skillFile.path, action: .skipped, reason: "没装过"))
        }
        return results
    }

    // MARK: - 实现

    /// CLAUDE.md 只在「用户自己建的普通文件」时写：不存在就跳过，
    /// 软链或与 AGENTS.md 指向同一文件也跳过（否则同一段说明会出现两次）。
    private func claudeSkipReason() -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: claudeFile.path) else {
            return "文件不存在（只写 ~/AGENTS.md）"
        }
        if let destination = try? fileManager.destinationOfSymbolicLink(atPath: claudeFile.path) {
            return "是软链（指向 \(destination)），不重复写"
        }
        if realPath(agentsFile) == realPath(claudeFile) {
            return "与 ~/AGENTS.md 是同一个文件"
        }
        return nil
    }

    private func realPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func writeBlock(to url: URL) throws -> AgentInstallResult {
        let target = url.resolvingSymlinksInPath()
        let fileManager = FileManager.default
        let existed = fileManager.fileExists(atPath: target.path)
        let existing = existed ? try String(contentsOf: target, encoding: .utf8) : ""
        let updated = Self.applyingBlock(to: existing)

        if existed && updated == existing {
            return AgentInstallResult(path: url.path, action: .unchanged, reason: nil)
        }
        try writeAtomically(updated, to: target)
        return AgentInstallResult(path: url.path, action: existed ? .updated : .created, reason: nil)
    }

    private func removeBlock(from url: URL) throws -> AgentInstallResult {
        let target = url.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: target.path) else {
            return AgentInstallResult(path: url.path, action: .skipped, reason: "文件不存在")
        }
        let existing = try String(contentsOf: target, encoding: .utf8)
        let updated = Self.removingBlock(from: existing)
        guard updated != existing else {
            return AgentInstallResult(path: url.path, action: .unchanged, reason: nil)
        }
        try writeAtomically(updated, to: target)
        return AgentInstallResult(path: url.path, action: .removed, reason: nil)
    }

    private func writeSkill() throws -> AgentInstallResult {
        let text = skillText.hasSuffix("\n") ? skillText : skillText + "\n"
        if let existing = try? String(contentsOf: skillFile, encoding: .utf8), existing == text {
            return AgentInstallResult(path: skillFile.path, action: .unchanged, reason: nil)
        }
        let existed = FileManager.default.fileExists(atPath: skillFile.path)
        try writeAtomically(text, to: skillFile)
        return AgentInstallResult(path: skillFile.path, action: existed ? .updated : .created, reason: nil)
    }

    private static func applyingBlock(to existing: String) -> String {
        let block = AgentSkill.block
        if let start = existing.range(of: AgentSkill.beginMarker),
           let end = existing.range(of: AgentSkill.endMarker, range: start.upperBound..<existing.endIndex) {
            return existing.replacingCharacters(in: start.lowerBound..<end.upperBound, with: block)
        }
        if existing.isEmpty { return block + "\n" }
        if existing.hasSuffix("\n\n") { return existing + block + "\n" }
        if existing.hasSuffix("\n") { return existing + "\n" + block + "\n" }
        return existing + "\n\n" + block + "\n"
    }

    private static func removingBlock(from existing: String) -> String {
        guard let start = existing.range(of: AgentSkill.beginMarker),
              let end = existing.range(of: AgentSkill.endMarker, range: start.upperBound..<existing.endIndex)
        else { return existing }

        var lower = start.lowerBound
        var upper = end.upperBound
        // 吃掉标记块后面的换行，再吃掉前面一个我们自己加的分隔换行
        while upper < existing.endIndex, existing[upper] == "\n" {
            upper = existing.index(after: upper)
        }
        if lower > existing.startIndex, existing[existing.index(before: lower)] == "\n" {
            lower = existing.index(before: lower)
        }
        var result = String(existing[..<lower] + existing[upper...])
        if !result.isEmpty && !result.hasSuffix("\n") {
            result += "\n"
        }
        return result
    }

    private func writeAtomically(_ text: String, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appending(path: ".\(url.lastPathComponent).utodo-\(UUID().uuidString)")
        try Data(text.utf8).write(to: temporary)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }
}
