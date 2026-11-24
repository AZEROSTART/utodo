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

    public static func particles(seed: UInt64) -> [Particle] {
        var rng = SplitMix64(state: seed)
        return (0..<particleCount).map { index in
            let firstWave = index < firstWaveCount
            let delay = firstWave
                ? Double.random(in: 0...0.02, using: &rng)
                : Double.random(in: 0.06...0.14, using: &rng)
            let angle = CGFloat.random(in: (-152 * .pi / 180)...(-28 * .pi / 180), using: &rng)

            var speed = CGFloat.random(in: 80...210, using: &rng)
            // 上升速度封顶 130pt/s，否则上半圆的粒子一秒内全部飞出画面
            let verticalLimit = 130 / -sin(angle)
            speed = min(speed, verticalLimit)

            return Particle(
                angle: angle,
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
