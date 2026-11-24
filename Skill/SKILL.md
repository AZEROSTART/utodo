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
- 标题以 `-` 开头时走 stdin：`printf '%s\n' "- 某事" | utodo add -`

## 记多条

```bash
printf '甲\n乙\n丙\n' | utodo add -
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
