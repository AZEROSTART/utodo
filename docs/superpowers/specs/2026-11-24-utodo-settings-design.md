# utodo 可调透明度（短设计）

日期：2026-11-24
状态：待确认

## 意图

卡片现在有两种"透明度"，都写死在代码里：

1. **玻璃底色**：`.ultraThinMaterial` 上叠的 30% 黑（`DesktopCardView.swift` 的 `GlassBackground`）。决定卡片看起来通不通透。
2. **全屏退让**：切到全屏 App 时整窗 alpha 降到 `0.55`（`Theme.dimAlpha`）。决定"自动变淡"变多淡。

需求：这两个值都能调，人用右键菜单随手改，agent 用命令行改，改完立即生效、下次启动还记得。

## 目标 / 非目标

- 目标：两个值都可配；人类不改文件也能调；agent 一条命令就能改并读回；App 实时应用
- 非目标：不做设置窗口、不做滑块、不做主题系统、不做按 App 记忆（不同 App 不同透明度）

## 存储

`~/Library/Application Support/utodo/config.json`，`UTODO_CONFIG` 可覆盖路径（测试用）。JSON：

```json
{ "glassOpacity": 0.3, "dimAlpha": 0.55 }
```

为什么不用 `UserDefaults`：CLI 是独立可执行文件，写另一个进程的 defaults 域既隐晦又有缓存坑；JSON 文件 agent 能直接 `cat`，原子写（临时文件 + rename）不会写出半个文件，App 和 CLI 用同一份解析代码（放 `UTodoCore`，可测）。

缺文件 / 缺键 / 值越界：用默认值，不报错（配置坏了不该让 App 起不来）。

## 参数

| 键 | 含义 | 默认 | 范围 |
| --- | --- | --- | --- |
| `glassOpacity` | 玻璃底色不透明度；0 只剩材质，越大越实心 | `0.30` | `0…1` |
| `dimAlpha` | 全屏退让时整窗 alpha | `0.55` | `0.05…1` |

## 给人：右键菜单

卡片右键 → 「透明度」子菜单：通透 `0.12` / 标准 `0.30` / 实心 `0.55`（当前项打勾）。改完写 JSON 并发通知，立即生效。

## 给 agent：agent 怎么知道有这些命令

agent 不会读 README，它只会先跑 `utodo --help`、`utodo`、或者照错误提示改。所以发现路径就这三个：

1. **`utodo --help` / 直接跑 `utodo`**：完整帮助打到 stdout、退出码 0（不是错误）。帮助里每个命令都带一行例子，`config` 部分写明两个键、范围、默认值，以及 `utodo config set glass 0.5` 这种可直接复制的例子。
2. **报错即说明书**：`utodo config set foo 1` → stderr 列出可用键（`glass`、`dim`）和一句例子，退出 2；`set glass 1.5` → 说明范围 `0…1` 并保留原值。agent 从错误里就能学会正确用法。
3. **`utodo config` 不带参数**：打印当前值和改法，一行一个：

   ```text
   glassOpacity=0.3    # 卡片玻璃底色，0 最透、1 最实；改：utodo config set glass 0.5
   dimAlpha=0.55       # 全屏时整窗 alpha；改：utodo config set dim 0.35
   ```

机器读用 `utodo config --json`；人读用不带参数的版本。

## 给 agent：`utodo config`

```bash
utodo config                       # 当前值 + 改法，一行一个
utodo config --json                # {"glassOpacity":0.3,"dimAlpha":0.55}
utodo config get glass             # 0.3
utodo config set glass 0.5         # glassOpacity: 0.3 → 0.5，立即上屏
utodo config set dim 0.35          # dimAlpha: 0.55 → 0.35
utodo config set glass 1.5         # stderr：超出范围 0…1，退出 2，文件不动
utodo config set foo 1             # stderr：未知键，列出可用键，退出 2
```

- 键名支持短别名：`glass` → `glassOpacity`，`dim` → `dimAlpha`
- 每次修改都打印 `旧值 → 新值`，agent 不用再读一次确认
- 修改是原子的，且立即 post `com.azerostart.utodo.configChanged`，App 收到后重读 JSON 并应用
- 退出码沿用 CLI 约定：`0` 成功（含 `--help`）/ `1` 没找到 / `2` 用法或取值错误

agent 的典型用法：`utodo config set glass 0.5`（想更实一点时），或 `utodo config --json` 先读现状再决定改多少。

## 退出码的调整

`utodo --help`、不带参数的 `utodo` 改成 **stdout + 退出 0**（现在是 stderr + 2）。理由：agent 探路时第一条命令通常是 `--help`，返回非零会被它当成"这工具坏了"；真正的用法错误（未知命令/参数、取值越界）仍然 `exit 2`。`Scripts/cli-smoke.sh` 里 `--help` 断言 2 要跟着改成 0。

## 实现要点

- `UTodoCore/AppConfig.swift`：`struct AppConfig: Codable, Equatable { glassOpacity, dimAlpha }` + `load/save/mergeDefaults`，越界回落默认值
- `ConfigStore` 负责路径、原子写、`UTODO_CONFIG`
- `GlassBackground` 接受 `opacity` 参数；`CardViewModel` 持有 `config`，收 `configChanged` 通知后重读
- `PanelController.applyAlpha()` 用 `config.dimAlpha` 而不是 `Theme.dimAlpha`
- CLI 的 `config` 子命令在开库之前处理（改配置不需要数据库）
- 右键菜单写配置 → CLI 与 App 共用 `ConfigStore`

## builder 自行决定

- JSON 里出现未知键：保留（不删），只追加/更新已知键
- 菜单里三档的具体数值：上面已定
- 是否给 `utodo config set` 加 `--json` 输出：不加，`config --json` 够用
