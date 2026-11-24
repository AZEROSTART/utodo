# utodo · 设计文档

2026-11-24

## 意图

一块常驻在桌面角落的玻璃卡片，永远显示当前最该做的几件事。打开电脑就在，瞟一眼就知道下一步。同时提供一个 `utodo` 命令，让 agent 随手把待办写进去，卡片上立刻出现。

给自己用，单人，本地，不联网。

## 目标

- 开机后自动出现在桌面右上角，安静、不抢焦点、不弹任何提示
- 一屏最多看到 5 条未完成事项，多了滚动
- 鼠标点一下就能新增，键盘也能敲完即走
- 切到全屏应用时，整张卡片变淡让路；鼠标移到上面立刻恢复
- `utodo add "..."` 一秒内出现在卡片上；App 没运行也不丢数据

## 非目标

不做：日期、提醒、重复任务、标签、优先级、多列表、拖拽排序、云同步、账号、iOS 版、通知横幅、App Store 分发。

## 反目标

以下任一出现就算失败：变成第二个 Things（开始做项目管理）；占掉屏幕一大块；抢走焦点或弹出任何对话框；CLI 必须先启动 App 才能写入。

## 约束

- 只支持 macOS 26 及以上（要用系统原生玻璃材质），Apple Silicon
- 本机自用，ad-hoc 签名，不做沙盒
- 不显示 Dock 图标，不进菜单栏
- 当前机器：macOS 27.2，Xcode 已装但 `xcode-select` 指向 Command Line Tools

## 已定的决定

### 形态

268pt 宽的无边框玻璃卡片，固定在屏幕右上角、避开菜单栏 24pt。高度随条数变化，5 条为上限，超出内部滚动。可拖动，位置按显示器记住。

交互（用户把这一块交给我定，以下是我拍板）：

- 卡片顶部常驻一行"＋ 添加一件事…"，点一下进入输入，回车入列，Esc 退出
- 全局快捷键 ⌥Space 唤出并聚焦输入行
- 每行悬停时右侧浮出勾与删除，不悬停时干净
- 点击行左侧圆圈标记完成；已完成折叠在列表底部，只显示数字，点开才展开
- 新加的排在最上面；未完成按创建时间倒序
- 卡片上右键出菜单：添加、显示已完成、退出。没有菜单栏图标、没有设置窗口
- 卡片不可成为主窗口，不抢焦点；输入时用 non-activating panel 只拿键盘

### 视觉

- 玻璃：系统材质 + 自定义 1px 内高光描边、20pt 圆角、两级阴影（大扩散 + 贴身）
- 排版：12.5pt 正文，30pt 行高，11pt 小节标题带字距，等宽数字
- 深色壁纸上以白字为主，跟随系统外观
- 动画：新增行 180ms 淡入并轻移，完成 200ms 淡出，透明度 300ms ease

### 透明退让

- 常态不透明
- 前台是全屏应用时，整卡 alpha 降到 0.55
- 鼠标悬停或正在输入时回到 1.0
- 只认"全屏"，普通窗口盖住它时不变化

### 数据

SQLite，WAL 模式，位置 `~/Library/Application Support/utodo/utodo.sqlite3`。

表 `todos`：`id`(TEXT, UUID)、`title`(TEXT)、`created_at`(REAL)、`completed_at`(REAL, 可空)。

### CLI

- `utodo add "标题"`，也支持 `echo "标题" | utodo add -`（多行拆成多条）
- `utodo list [--json]` 列出未完成，按展示顺序
- `utodo done <短id>`、`utodo rm <短id>`，短 id 取 UUID 前 8 位，唯一前缀匹配
- `utodo --version`
- 退出码：0 成功，1 没找到，2 用法错误
- 输出默认人读的一行结果，`--json` 时才吐 JSON

### App 与 CLI 的通信

CLI 直接打开同一个 SQLite 写入，写完发一个 `DistributedNotificationCenter` 通知；App 收到立即刷新。App 另外在窗口激活时重读一次兜底。因此 App 关闭时 CLI 照样能写，下次打开就看到。

### 技术路线

选定方案 A：SwiftUI 界面 + 一层很薄的 AppKit 承载窗口。

被否掉的：

- B. Tauri / Electron：玻璃是 CSS 仿的，全屏层级与多桌面要打补丁，包体和内存大
- C. CLI 只往 inbox 目录丢文件：实现最省事，但 agent 读不到真实状态、也改不了

## 交给 builder 的部分

- 工程组织：Swift Package `UTodoCore`（模型 + Store + 通知名）被 `UTodoApp` 和 `utodo` 两个 target 共用；用脚本把 app target 打成 `UTodo.app` 并 ad-hoc 签名。允许改用 Xcode 工程，只要 `utodo` CLI 与 App 共享同一份 Store 代码
- 窗口层级的实现细节：`NSPanel` 的 `level` 与 `collectionBehavior`（要浮在全屏之上、跟随所有 Space）、non-activating 与输入焦点的配合
- 全屏检测的具体判据（`CGWindowListCopyWindowInfo` 或 `NSWorkspace` 事件）
- 滚动、悬停态、拖动的具体实现
- 单元测试（Store 层）与 CLI 端到端测试的写法
- 构建脚本与安装步骤（把 `utodo` 放到 PATH 上）

## 已知风险，第一版要先验证

1. 无边框 non-activating panel 能不能稳定盖在全屏应用之上，同时又能拿到键盘输入
2. 没有 Dock 图标、没有菜单栏图标时，右键退出是否足够（可能需要在卡片上加一个极小的隐藏入口）
3. 全屏检测的误判率：误判会让卡片莫名其妙变淡
