import CoreGraphics
import Foundation

/// 完成一件事时从圆圈炸开的彩纸。粒子表由 seed 完全决定：同 seed 同结果，
/// 轨迹在 `Firework.position/opacity/rotation` 里按时间解析求值，不存每帧数组。
public enum Firework {
    public static let particleCount = 52
    /// 第一批立刻炸开，其余延迟 60–140ms 形成余爆
    public static let firstWaveCount = 34
    public static let colorCount = 5
    public static let maxLifetime: TimeInterval = 1.0
    /// 卡片只有约 200pt 高，重力再大彩纸会在 0.3 秒内全掉出画面
    public static let gravity: CGFloat = 260

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

        public init(
            angle: CGFloat,
            speed: CGFloat,
            delay: TimeInterval,
            life: TimeInterval,
            length: CGFloat,
            thickness: CGFloat,
            spin: CGFloat,
            colorIndex: Int,
            sparkle: Bool
        ) {
            self.angle = angle
            self.speed = speed
            self.delay = delay
            self.life = life
            self.length = length
            self.thickness = thickness
            self.spin = spin
            self.colorIndex = colorIndex
            self.sparkle = sparkle
        }
    }

    public static func particles(seed: UInt64) -> [Particle] {        var rng = SplitMix64(state: seed)
        return (0..<particleCount).map { index in
            let firstWave = index < firstWaveCount
            let delay = firstWave
                ? Double.random(in: 0...0.02, using: &rng)
                : Double.random(in: 0.06...0.14, using: &rng)

            // 按速度分量采样再合成：只夹纵向会把爆点压成一条横线，
            // 两个分量都夹住才是圆的绽放
            let velocityX = CGFloat.random(in: -70...200, using: &rng)
            let velocityY = CGFloat.random(in: -170...(-20), using: &rng)
            let speed = hypot(velocityX, velocityY)
            let burstAngle = atan2(velocityY, velocityX)

            return Particle(
                angle: burstAngle,
                speed: speed,
                delay: delay,
                life: Double.random(in: 0.7...1.0, using: &rng),
                length: CGFloat.random(in: 4...7, using: &rng),
                thickness: CGFloat.random(in: 1.6...3.2, using: &rng),
                spin: CGFloat.random(in: -9.42...9.42, using: &rng),
                colorIndex: Int.random(in: 0..<colorCount, using: &rng),
                sparkle: Int.random(in: 0..<5, using: &rng) == 0
            )
        }
    }

    // MARK: - 轨迹（解析求值，不存每帧）

    /// 粒子在 `t` 秒时的位置；`t` 超过寿命后停在寿命终点（由透明度负责让它消失）
    public static func position(_ p: Particle, at t: TimeInterval, origin: CGPoint) -> CGPoint {
        let c = clampedTime(p, at: t)
        // 空气阻尼：横向扩散不会冲出卡片，竖向保留一点飘落感
        let damping = max(0, 1 - 0.5 * c)
        return CGPoint(
            x: origin.x + cos(p.angle) * p.speed * c * damping,
            y: origin.y + sin(p.angle) * p.speed * c * damping + 0.5 * gravity * c * c
        )
    }

    /// 1 → 0 的淡出：前 65% 寿命不透明，之后线性消失
    public static func opacity(_ p: Particle, at t: TimeInterval) -> CGFloat {
        let local = t - p.delay
        guard local > 0, local < p.life else { return local == 0 ? 1 : 0 }
        let fadeStart = 0.65 * p.life
        guard local > fadeStart else { return 1 }
        return CGFloat(1 - (local - fadeStart) / (p.life - fadeStart))
    }

    public static func rotation(_ p: Particle, at t: TimeInterval) -> CGFloat {
        p.spin * clampedTime(p, at: t)
    }

    /// 起爆点到卡片边缘至少留这么多，否则冲击环大半被圆角裁掉
    public static let originInset: CGFloat = 14

    /// 完成最后一行时卡片会立刻变矮，原来的行坐标可能已经落到卡片外；
    /// 把起爆点夹回可见区域，保证环和彩纸出现在眼前
    public static func clampOrigin(_ origin: CGPoint, cardSize: CGSize, inset: CGFloat = originInset) -> CGPoint {
        func clamp(_ value: CGFloat, upper: CGFloat) -> CGFloat {
            guard upper > inset * 2 else { return upper / 2 }
            return min(max(value, inset), upper - inset)
        }
        return CGPoint(x: clamp(origin.x, upper: cardSize.width), y: clamp(origin.y, upper: cardSize.height))
    }

    private static func clampedTime(_ p: Particle, at t: TimeInterval) -> CGFloat {
        CGFloat(min(max(0, t - p.delay), p.life))
    }
}

/// 自带的确定性随机数：不依赖系统随机源，同 seed 每次得到同一组彩纸
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(state: UInt64) {
        self.state = state
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
