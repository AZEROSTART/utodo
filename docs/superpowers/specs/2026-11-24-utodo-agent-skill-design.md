# utodo agent skill（短设计）

日期：2026-11-24
状态：待确认

## 意图

这个仓库是给别人下载用的。别人的 AI 需要三件事才能用上 utodo：

1. 知道它存在、什么时候该用（用户说"记个待办""帮我记一下""别忘了 X"时）
2. 会自己装（装 App + CLI），会验证装没装上
3. 会用它（加、列、完成、删、清、调透明度），知道退出码和短 id 规则

## 交付形态

skill 正文放仓库 `Skill/SKILL.md`（带 frontmatter，OpenCode / Claude Code 这类支持 skill 目录的工具可以直接拷），同时**内嵌进 CLI 二进制**，这样 `utodo agent install` 不需要用户还留着仓库目录。

真正的"触发器"靠追加到用户全局指令文件里的一小段：

| 写入目标 | 条件 |
| --- | --- |
| `~/AGENTS.md` | 总是（不存在就创建） |
| `~/.claude/CLAUDE.md` | 该文件已存在，且真实路径与 `~/AGENTS.md` 不同（不是软链） |

写入内容带标记，可重复安装、可整段卸载：

```markdown
<!-- utodo:begin（由 `utodo agent install` 写入，勿手改） -->
## 待办：utodo

用户说"记个待办 / 帮我记一下 / 别忘了 X / 提醒我 X"时，用 `utodo` 记下来，
不要只在聊天里复述。它是一张常驻桌面右上角的卡片，写入 1 秒内上屏。

- 记一条：`utodo add "18:30 前交季度报表"`
- 记多条：`printf '甲\n乙\n' | utodo add -`（首行排最上）
- 看未完成：`utodo list`
- 完成/删除：`utodo done <8位id前缀>` / `utodo rm <8位id前缀>`
- 清除已完成：`utodo clear`
- 调透明度：`utodo config`、`utodo config set glass 0.5`
- 没装就先装：`git clone https://github.com/AZEROSTART/utodo && cd utodo && ./Scripts/install.sh`

退出码 0 成功 / 1 没找到或前缀有歧义 / 2 用法错误。完整说明见
`~/.local/share/utodo/SKILL.md` 或 `utodo --help`。
<!-- utodo:end -->
```

## 命令

```bash
utodo agent install      # 写 SKILL.md + 追加 AGENTS.md 块；幂等，重复跑只更新不重复
utodo agent print        # 只打印要追加的块（想手动贴的人用）
utodo agent uninstall    # 删掉自己写过的块和 SKILL.md
```

- 安装前打印每个目标路径和动作（新增 / 更新 / 跳过），不静默改用户的文件
- 文件写入用原子替换（临时文件 + rename），保留原文件其余内容与换行风格
- 遇到写不进去（权限）→ stderr 说明原因 + 退出 1，不半途而废
- `Scripts/install.sh` 结尾提示：想让 AI 会用，跑 `utodo agent install`

## SKILL.md 的主要内容

- 何时使用 / 不要用（用户只是问"今天几号"之类不要记）
- 安装与自检（`utodo --version`、`utodo list`、卡片是否在跑）
- 全部命令与退出码
- 短 id 规则（前缀唯一，歧义时写长一点）
- 透明度两个键的含义与范围
- 常见坑：`add` 的空标题会被忽略；标题里的 `--json` 要加引号或用 `--`；卡片不弹通知，别重复写

## 非目标

- 不做各 agent 专属的 skill 目录探测（`~/.claude/skills/...`、`~/.config/opencode/skill/...`）——先把通用指令文件这条路做扎实，用户想用 skill 目录可以自己拷 `Skill/SKILL.md`
- 不改用户其他指令文件（Cursor rules、Copilot instructions 等）
