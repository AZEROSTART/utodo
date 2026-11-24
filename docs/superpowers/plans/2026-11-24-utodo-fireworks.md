# utodo 完成烟花特效 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 点圆圈或标题完成一件事时，从圆圈处炸开一圈金色冲击环 + 52 颗彩色细长彩纸，约 1 秒内飘落淡出，整卡轻微脉冲一次。

**Architecture:** 粒子表与轨迹是 `UTodoCore` 里的纯函数（固定 seed 可复现、可单测），App 层用 `Canvas` + `TimelineView` 按当前时间解析求值绘制，不保存每帧数组。起爆点由行内 `GeometryReader` 的 preference 提供，随完成动作一次性传给 `CardViewModel`，再存进最多 3 组的 `BurstList`。粒子层 `allowsHitTesting(false)`，按卡片圆角裁剪。

**Tech Stack:** Swift 6 / SwiftUI / CoreGraphics / Swift Testing，macOS 26，无新增依赖。

**Spec:** `docs/superpowers/specs/2026-11-24-utodo-fireworks-design.md`

## Global Constraints

- 构建与测试前必须 `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- 测试用 `swift test -j 1`（并行链接偶发 undefined symbols）
- 产品名 `UTodoApp` 保持不变；只有打包脚本把产物拷成 `UTodo`
- 不加第三方依赖、不改 CLI、不改配置文件结构
- 提交信息沿用仓库风格：`feat: ...` / `style: ...` / `test: ...`，中文描述
- SwiftUI 坐标 y 向下为正：向上飞 = 负的 y 位移，重力 = 正的 y 增加

---

## Review Focus

1. **连点多个任务**：粒子最多同时 3 组，最旧的被丢弃，不能越积越多或让 `CardViewModel` 卡住 —— Task 3 的 cap 测试 + Task 4 的清理任务。
2. **列表滚动到第 6 条以后完成**：起爆点必须跟实际可见位置一致，不能按 `active` 下标猜 —— Task 4 用行 frame preference，手工验证。
3. **系统开启「减弱动态效果」**：只能做冲击环 + 卡片脉冲，不撒粒子 —— Task 4 提供 `UTODO_REDUCE_MOTION=1` 覆盖，预览可验。
4. **完成最后一条导致卡片瞬间变矮**：粒子层不能被立刻清掉或错位 —— Task 4 的 overlay 独立于行，清理只按时间。
5. **坐标系符号**：SwiftUI y 向下，向上飞与重力方向写反会让彩纸往天上掉 —— Task 2 的方向测试。

---

### Task 1: 粒子表（`Firework.particles`）

**Files:**
- Create: `Sources/UTodoCore/Firework.swift`
- Test: `Tests/UTodoCoreTests/FireworkTests.swift`

**Interfaces:**
- Consumes: 无
- Produces: `public enum Firework`，含 `particleCount: Int = 52`、`colorCount: Int = 5`、`maxLifetime: TimeInterval = 1.0`、`gravity: CGFloat = 260`、`public struct Particle: Equatable, Sendable`、`public static func particles(seed: UInt64) -> [Particle]`

Particle 精确定义（本任务全部字段）：

```swift
public struct Particle: Equatable, Sendable {
    public let angle: CGFloat      // 弧度，-π 到 0 为上半圆
    public let speed: CGFloat      // pt/s
    public let delay: TimeInterval // 秒
    public let life: TimeInterval  // 秒
    public let length: CGFloat     // 彩纸长边
    public let thickness: CGFloat  // 彩纸短边
    public let spin: CGFloat       // 弧度/秒
    public let colorIndex: Int     // 0..<colorCount
    public let sparkle: Bool       // true = 小圆亮片，false = 细长彩纸
    public init(angle: CGFloat, speed: CGFloat, delay: TimeInterval, life: TimeInterval,
                length: CGFloat, thickness: CGFloat, spin: CGFloat, colorIndex: Int, sparkle: Bool)
}
```

- [ ] **Step 1: 写失败测试**

```swift
import CoreGraphics
import Testing
@testable import UTodoCore

@Suite struct FireworkTests {
    @Test func sameSeedIsReproducible() {
        #expect(Firework.particles(seed: 7) == Firework.particles(seed: 7))
    }

    @Test func differentSeedsDiffer() {
        #expect(Firework.particles(seed: 7) != Firework.particles(seed: 8))
    }

    @Test func burstShape() {
        let particles = Firework.particles(seed: 42)
        #expect(particles.count == Firework.particleCount)
        #expect(particles.count == 52)

        let firstWave = particles.prefix(34)
        let secondWave = particles.dropFirst(34)
        #expect(firstWave.allSatisfy { (0...0.02).contains($0.delay) })
        #expect(secondWave.allSatisfy { (0.06...0.14).contains($0.delay) })

        for p in particles {
            #expect((0.7...1.0).contains(p.life))
            #expect((CGFloat(4)...CGFloat(7)).contains(p.length))
            #expect((CGFloat(1.6)...CGFloat(3.2)).contains(p.thickness))
            #expect(abs(p.spin) <= 9.5)
            #expect((0..<Firework.colorCount).contains(p.colorIndex))
            #expect((CGFloat(-152) * .pi / 180 ... CGFloat(-28) * .pi / 180).contains(p.angle))
            // 上升速度封顶：卡片只有 200pt 高，初速全给向上会瞬间出画
            #expect(sin(p.angle) * p.speed >= -130.001)
        }

        let sparkles = particles.filter(\.sparkle)
        #expect(!sparkles.isEmpty && sparkles.count < particles.count)
    }
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift test -j 1 --filter FireworkTests`
Expected: 编译失败，`cannot find 'Firework' in scope`

- [ ] **Step 3: 实现 `Sources/UTodoCore/Firework.swift`**

用 SplitMix64 自带的随机数生成器（不依赖 `SystemRandomNumberGenerator`，保证同 seed 同结果）。生成规则：

- `i < 34` 为第一批，`delay` 取 `0...0.02`；其余 18 颗 `delay` 取 `0.06...0.14`
- `angle` 取 `-152°...-28°`，`speed` 取 `80...210`，随后把 `speed` 夹到 `sin(angle) * speed >= -130`（即 `speed = min(speed, 130 / -sin(angle))`）
- `life` 取 `0.7...1.0`，`length` 取 `4...7`，`thickness` 取 `1.6...3.2`
- `spin` 取 `-9.42...9.42`（±540°/s）
- `colorIndex` 取 `0..<5`，`sparkle` 每 5 颗约 1 颗（`Int.random(in: 0..<5, using: &rng) == 0`）

`particles(seed:)` 每次调用都从头生成同一组（不要缓存，成本可忽略）。

- [ ] **Step 4: 跑测试确认通过**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift test -j 1 --filter FireworkTests`
Expected: 4 个测试全 PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/UTodoCore/Firework.swift Tests/UTodoCoreTests/FireworkTests.swift
git commit -m "feat: 完成特效的彩纸粒子表（同 seed 可复现）"
```

---

### Task 2: 粒子轨迹（位置 / 透明度 / 自旋）

**Files:**
- Modify: `Sources/UTodoCore/Firework.swift`
- Test: `Tests/UTodoCoreTests/FireworkTests.swift`（追加一个 `@Suite struct FireworkMotionTests`）

**Interfaces:**
- Consumes: Task 1 的 `Firework.Particle`、`Firework.gravity`
- Produces:
  - `public static func position(_ p: Particle, at t: TimeInterval, origin: CGPoint) -> CGPoint`
  - `public static func opacity(_ p: Particle, at t: TimeInterval) -> CGFloat`
  - `public static func rotation(_ p: Particle, at t: TimeInterval) -> CGFloat`

语义（`local = max(0, t - p.delay)`，`clamped = min(local, p.life)`）：

- `position`：`damping = max(0, 1 - 0.35 * clamped)`；`x = origin.x + cos(angle) * speed * clamped * damping`；`y = origin.y + sin(angle) * speed * clamped * damping + 0.5 * gravity * clamped * clamped`
- `opacity`：`t < delay` 返回 0；`local < 0.65 * life` 返回 1；之后线性降到 0（`local >= life` 为 0）
- `rotation`：`spin * clamped`

- [ ] **Step 1: 写失败测试**

```swift
@Suite struct FireworkMotionTests {
    private func particle(angle: CGFloat = -.pi / 2, speed: CGFloat = 100, delay: TimeInterval = 0,
                          life: TimeInterval = 0.8, spin: CGFloat = 4) -> Firework.Particle {
        Firework.Particle(angle: angle, speed: speed, delay: delay, life: life,
                          length: 5, thickness: 2, spin: spin, colorIndex: 0, sparkle: false)
    }

    @Test func startsAtOrigin() {
        let origin = CGPoint(x: 26, y: 100)
        let p = Firework.position(particle(), at: 0, origin: origin)
        #expect(abs(p.x - origin.x) < 0.001 && abs(p.y - origin.y) < 0.001)
        #expect(Firework.opacity(particle(), at: 0) == 1)
    }

    @Test func everyParticleStartsAtOriginAndEndsInvisible() {
        let origin = CGPoint(x: 26, y: 100)
        let end = Firework.maxLifetime + 0.15
        for seed in UInt64(1)...50 {
            for p in Firework.particles(seed: seed) {
                #expect(Firework.position(p, at: 0, origin: origin) == origin)
                #expect(Firework.opacity(p, at: end) == 0)
            }
        }
    }

    @Test func fliesUpThenFallsDown() {
        let origin = CGPoint(x: 26, y: 100)
        let up = Firework.position(particle(), at: 0.15, origin: origin)
        #expect(up.y < origin.y) // SwiftUI y 向下：向上飞是更小的 y
        let down = Firework.position(particle(), at: 0.8, origin: origin)
        #expect(down.y > up.y)
    }

    @Test func delayedParticlesWaitAtOrigin() {
        let origin = CGPoint(x: 26, y: 100)
        let p = particle(delay: 0.1)
        #expect(Firework.opacity(p, at: 0.05) == 0)
        let pos = Firework.position(p, at: 0.05, origin: origin)
        #expect(pos == origin)
    }

    @Test func fadesOutAtEndOfLife() {
        let p = particle(life: 0.8)
        #expect(Firework.opacity(p, at: 0.4) == 1)
        #expect(Firework.opacity(p, at: 0.8) == 0)
        #expect(Firework.opacity(p, at: 2.0) == 0)
    }

    @Test func rotationGrowsWithTime() {
        let p = particle(spin: 4)
        #expect(abs(Firework.rotation(p, at: 0.2) - 0.8) < 0.001)
        #expect(Firework.rotation(p, at: 0.4) > Firework.rotation(p, at: 0.2))
    }

    @Test func staysNearTheCard() {
        let origin = CGPoint(x: 26, y: 100)
        for seed in UInt64(1)...50 {
            for p in Firework.particles(seed: seed) {
                for step in 0...25 {
                    let t = Double(step) / 25 * Firework.maxLifetime
                    let pos = Firework.position(p, at: t, origin: origin)
                    #expect(pos.x >= -80 && pos.x <= 348)
                }
            }
        }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift test -j 1 --filter FireworkMotionTests`
Expected: 编译失败，`cannot find 'position'` / `'opacity'` / `'rotation'`

- [ ] **Step 3: 实现三个纯函数**

按上面的语义直接写，坐标用 `CoreGraphics`，不加缓动库、不存中间帧。

- [ ] **Step 4: 跑测试确认通过**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift test -j 1 --filter Firework`
Expected: Task 1 与 Task 2 全部 PASS（若 `staysNearTheCard` 失败，调小 `speed` 上限或加大阻尼，不要放宽断言）

- [ ] **Step 5: 提交**

```bash
git add Sources/UTodoCore/Firework.swift Tests/UTodoCoreTests/FireworkTests.swift
git commit -m "feat: 彩纸轨迹与淡出（解析求值，不存每帧）"
```

---

### Task 3: 最多 3 组的同时爆点（`BurstList`）

**Files:**
- Create: `Sources/UTodoCore/FireworkBurst.swift`
- Test: `Tests/UTodoCoreTests/FireworkBurstTests.swift`

**Interfaces:**
- Consumes: `Firework.maxLifetime`
- Produces:

```swift
public struct FireworkBurst: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let origin: CGPoint
    public let seed: UInt64
    public let startedAt: Date
    public init(id: UUID = UUID(), origin: CGPoint, seed: UInt64, startedAt: Date)
}

public struct BurstList: Equatable {
    public static let limit = 3
    public private(set) var bursts: [FireworkBurst]
    public init()
    public var isEmpty: Bool
    public mutating func append(_ burst: FireworkBurst)   // 超过 3 组丢最旧
    public mutating func prune(at now: Date)               // 去掉超过 maxLifetime + 0.15 的
}
```

- [ ] **Step 1: 写失败测试**

```swift
import CoreGraphics
import Foundation
import Testing
@testable import UTodoCore

@Suite struct FireworkBurstTests {
    private func burst(_ offset: TimeInterval, now: Date = Date(timeIntervalSince1970: 1_000)) -> FireworkBurst {
        FireworkBurst(origin: CGPoint(x: 26, y: 100), seed: 1, startedAt: now.addingTimeInterval(offset))
    }

    @Test func keepsOnlyNewestThree() {
        var list = BurstList()
        let now = Date(timeIntervalSince1970: 1_000)
        for offset in [-3.0, -2.0, -1.0, 0.0] {
            list.append(burst(offset, now: now))
        }
        #expect(list.bursts.count == BurstList.limit)
        #expect(list.bursts.map(\.startedAt) == [-2.0, -1.0, 0.0].map { now.addingTimeInterval($0) })
    }

    @Test func pruneDropsExpiredOnly() {
        var list = BurstList()
        let now = Date(timeIntervalSince1970: 1_000)
        list.append(burst(-2.0, now: now))
        list.append(burst(-0.5, now: now))
        list.append(burst(0, now: now))
        list.prune(at: now)
        #expect(list.bursts.count == 2)
        #expect(list.bursts.first?.startedAt == now.addingTimeInterval(-0.5))
    }

    @Test func pruneKeepsFreshBursts() {
        var list = BurstList()
        let now = Date(timeIntervalSince1970: 1_000)
        list.append(burst(0, now: now))
        list.prune(at: now.addingTimeInterval(0.5))
        #expect(list.bursts.count == 1)
        #expect(!list.isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift test -j 1 --filter FireworkBurstTests`
Expected: 编译失败，`cannot find 'BurstList' in scope`

- [ ] **Step 3: 实现 `Sources/UTodoCore/FireworkBurst.swift`**

`append` 先 `while bursts.count >= Self.limit { bursts.removeFirst() }` 再追加；`prune` 用 `now.timeIntervalSince(burst.startedAt) >= Firework.maxLifetime + 0.15` 过滤。

- [ ] **Step 4: 跑测试确认通过**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift test -j 1 --filter FireworkBurstTests`
Expected: 3 个测试全 PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/UTodoCore/FireworkBurst.swift Tests/UTodoCoreTests/FireworkBurstTests.swift
git commit -m "feat: 同时最多 3 组烟花，按时间清理"
```

---

### Task 4: 接进卡片（起爆点、粒子层、卡片脉冲、预览）

**Files:**
- Create: `Sources/UTodoApp/FireworksOverlay.swift`
- Modify: `Sources/UTodoApp/CardViewModel.swift`（`complete(_:)` 签名、`bursts`、`addBurst`）
- Modify: `Sources/UTodoApp/DesktopCardView.swift`（行 frame preference、点击传起点、overlay + clip + 脉冲）
- Modify: `Sources/UTodoApp/PreviewRenderer.swift`（`UTODO_PREVIEW_BURST` 定格预览）
- Modify: `README.md:84-93`（交互表加一行）

**Interfaces:**
- Consumes: Task 1–3 的 `Firework`、`FireworkBurst`、`BurstList`
- Produces:
  - `CardViewModel.bursts: BurstList`（`private(set)`）
  - `CardViewModel.complete(_ todo: Todo, burstAt origin: CGPoint?)`
  - `CardViewModel.addBurst(at origin: CGPoint, startedAt: Date = Date())`（internal，预览用）
  - `struct FireworksOverlay: View { init(bursts: [FireworkBurst], reduceMotion: Bool = false, frozenAt: Date? = nil) }`

- [ ] **Step 1: `CardViewModel` 记录爆点**

```swift
private(set) var bursts = BurstList()

func complete(_ todo: Todo, burstAt origin: CGPoint?) {
    guard let store else { return }
    do {
        _ = try store.complete(idPrefix: todo.id.uuidString)
        reload()
        if let origin { addBurst(at: origin) }
        postStoreChanged()
    } catch {
        loadError = "没标上完成：\(describe(error))"
    }
}

func addBurst(at origin: CGPoint, startedAt: Date = Date()) {
    bursts.append(FireworkBurst(origin: origin, seed: .random(in: 0..<UInt64.max), startedAt: startedAt))
    let wait = max(0, startedAt.addingTimeInterval(Firework.maxLifetime + 0.2).timeIntervalSinceNow)
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(wait))
        bursts.prune(at: Date())
    }
}
```

- [ ] **Step 2: 新建 `FireworksOverlay.swift`**

`TimelineView(.animation)` + `Canvas` 按 `timeline.date` 求值；冲击环 0.25 秒内半径 6→34、线宽 1.4、金色 `Color(red: 1.0, green: 0.83, blue: 0.47)` 淡出；`reduceMotion == true` 时只画环。配色数组固定 5 项（顺序必须对应 `colorIndex` 0…4）：

```swift
static let palette: [Color] = [
    Color(red: 1.00, green: 0.83, blue: 0.47), // 金
    Color(red: 1.00, green: 0.42, blue: 0.54), // 桃红
    Color(red: 0.43, green: 0.91, blue: 0.78), // 薄荷
    Color(red: 0.42, green: 0.71, blue: 1.00), // 亮蓝
    Color(red: 1.00, green: 0.96, blue: 0.90), // 暖白
]
```

绘制细节：`sparkle` 粒子画圆（直径 = thickness）；其余画 `CGRect(x: -t/2, y: -length/2, ...)` 的圆角矩形（corner 0.6），先 `translateBy(position)` 再 `rotate(by: rotation)`。整层 `.allowsHitTesting(false)`。`frozenAt` 非 nil 时不包 `TimelineView`，直接 `Canvas` 用该时间画一帧（供 `ImageRenderer`）。

- [ ] **Step 3: `DesktopCardView` 取行位置并在点击时起爆**

在 `DesktopCardView` 里加：

```swift
@State private var rowFrames: [UUID: CGRect] = [:]
@State private var pulse = false

private struct RowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
```

行视图（`row(_:)`）在 `.frame(height: Theme.rowHeight)` 之后、`.contentShape` 之前插入：

```swift
.background {
    GeometryReader { proxy in
        Color.clear.preference(
            key: RowFramePreferenceKey.self,
            value: [todo.id: proxy.frame(in: .named("card"))]
        )
    }
}
```

主 VStack 在 `.frame(width: Theme.cardWidth, alignment: .top)` 之后加 `.coordinateSpace(name: "card")` 与 `.onPreferenceChange(RowFramePreferenceKey.self) { rowFrames = $0 }`。

圆圈按钮和标题点击都改走同一个方法（圆心 = 行 frame 的 `minX + 12`，因为行内左边距 4 + 圆半径 8）：

```swift
private func complete(_ todo: Todo) {
    let origin = rowFrames[todo.id].map { CGPoint(x: $0.minX + 12, y: $0.midY) }
    model.complete(todo, burstAt: origin)
}
```

- [ ] **Step 4: 粒子层、裁剪、脉冲、减弱动态**

在 `.background(GlassBackground(...))` 之后、`.shadow(...)` 之前：

```swift
.overlay {
    if !model.bursts.isEmpty {
        FireworksOverlay(
            bursts: model.bursts.bursts,
            reduceMotion: reduceMotion,
            frozenAt: isPreview ? Date() : nil
        )
    }
}
.clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
```

`reduceMotion` 计算属性（`UTODO_REDUCE_MOTION=1` 便于预览验证）：

```swift
private var reduceMotion: Bool {
    ProcessInfo.processInfo.environment["UTODO_REDUCE_MOTION"] != nil
        || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}
```

脉冲：`.scaleEffect(pulse ? 1.015 : 1.0)`，并加

```swift
.onChange(of: model.bursts.bursts.count) { _, count in
    guard count > 0 else { return }
    withAnimation(.easeOut(duration: 0.10)) { pulse = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
        withAnimation(.easeOut(duration: 0.18)) { pulse = false }
    }
}
```

- [ ] **Step 5: 预览定格一帧**

`PreviewRenderer` 在 `model.showsCompleted = true` 之后加：

```swift
if ProcessInfo.processInfo.environment["UTODO_PREVIEW_BURST"] != nil {
    model.addBurst(at: CGPoint(x: 26, y: 113), startedAt: Date().addingTimeInterval(-0.3))
}
```

- [ ] **Step 6: README 交互表**

在 `README.md` 的交互表「点左边的圈或标题」一行后加：

```markdown
| 完成一件事 | 圆圈处炸开彩纸，约 1 秒飘落淡出（系统开了「减弱动态效果」时只留冲击环和卡片脉冲） |
```

- [ ] **Step 7: 编译 + 全量测试**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; swift build && swift test -j 1`
Expected: build 成功；所有测试 PASS（含原有 40+ 个）

- [ ] **Step 8: 出预览图，人眼验收**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
UTODO_PREVIEW_BURST=1 swift run UTodoApp --render-preview /tmp/utodo-fireworks.png
UTODO_PREVIEW_BURST=1 UTODO_REDUCE_MOTION=1 swift run UTodoApp --render-preview /tmp/utodo-fireworks-reduced.png
```

Expected：第一张能看到金色冲击环 + 彩色彩纸散开、都在卡片圆角内；第二张只有冲击环，没有彩纸。

- [ ] **Step 9: 手工验证真机三件事**

1. 跑 `swift run UTodoApp`，点第 2 条圆圈：彩纸从圆圈起爆、约 1 秒消失、不挡住后续点击
2. 连点 3 条：三次都有烟花，不卡顿；点完立刻还能继续点
3. 加 7 条让列表滚动，滚到最下面完成一条：起爆点跟着被点的那一行，不是跟着列表顶部

- [ ] **Step 10: 提交**

```bash
git add Sources/UTodoApp/FireworksOverlay.swift Sources/UTodoApp/CardViewModel.swift Sources/UTodoApp/DesktopCardView.swift Sources/UTodoApp/PreviewRenderer.swift README.md
git commit -m "feat: 完成后圆圈处炸开彩纸，卡片轻脉冲"
```

---

### Task 5: 装机并确认

**Files:** 无源码改动

- [ ] **Step 1: 安装**

```bash
cd /Users/presence/dev-for-one/doanyApp/UTodo
./Scripts/install.sh
```

Expected：`App: /Users/presence/Applications/UTodo.app`，脚本最后 `open` 新版本

- [ ] **Step 2: 确认真机**

点一条待办，看到彩纸；再点一条，确认仍正常。若特效位置偏移或太淡，记录现象后回到 Task 4 调数值（粒子数、透明度、脉冲幅度），不改变结构。

- [ ] **Step 3: 确认无回归**

- 拖动标题条仍能移动卡片
- 右键菜单 / 透明度三档正常
- 全屏 App 在前面时卡片淡出，悬停恢复
- `utodo list` / `utodo add` 正常
