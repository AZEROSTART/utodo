import SwiftUI
import UTodoCore

/// 完成时从圆圈炸开的彩纸。全部按 `Firework` 的解析式逐帧求值，不存每帧数组。
/// 不参与命中测试，按卡片圆角裁剪；`frozenAt` 供 ImageRenderer 定格一帧。
struct FireworksOverlay: View {
    let bursts: [FireworkBurst]
    var reduceMotion = false
    var frozenAt: Date?

    /// 顺序必须对应 `Firework.Particle.colorIndex` 0…4
    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.83, blue: 0.47), // 金
        Color(red: 1.00, green: 0.42, blue: 0.54), // 桃红
        Color(red: 0.43, green: 0.91, blue: 0.78), // 薄荷
        Color(red: 0.42, green: 0.71, blue: 1.00), // 亮蓝
        Color(red: 1.00, green: 0.96, blue: 0.90), // 暖白
    ]

    var body: some View {
        Group {
            if let frozenAt {
                Canvas { context, _ in paint(at: frozenAt, in: &context) }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, _ in paint(at: timeline.date, in: &context) }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func paint(at date: Date, in context: inout GraphicsContext) {
        for burst in bursts {
            let elapsed = date.timeIntervalSince(burst.startedAt)
            guard elapsed >= 0, elapsed <= Firework.maxLifetime + 0.15 else { continue }
            drawRing(elapsed: elapsed, origin: burst.origin, in: &context)
            guard !reduceMotion else { continue }

            for particle in Firework.particles(seed: burst.seed) {
                let alpha = Firework.opacity(particle, at: elapsed)
                guard alpha > 0.001 else { continue }
                let point = Firework.position(particle, at: elapsed, origin: burst.origin)
                let color = Self.palette[particle.colorIndex].opacity(Double(alpha))

                if particle.sparkle {
                    let diameter = particle.thickness
                    let rect = CGRect(
                        x: point.x - diameter / 2,
                        y: point.y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                } else {
                    var layer = context
                    layer.translateBy(x: point.x, y: point.y)
                    layer.rotate(by: .radians(Firework.rotation(particle, at: elapsed)))
                    let rect = CGRect(
                        x: -particle.thickness / 2,
                        y: -particle.length / 2,
                        width: particle.thickness,
                        height: particle.length
                    )
                    layer.fill(Path(roundedRect: rect, cornerRadius: 0.6), with: .color(color))
                }
            }
        }
    }

    private func drawRing(elapsed: TimeInterval, origin: CGPoint, in context: inout GraphicsContext) {
        let t = min(1, elapsed / 0.25)
        guard t < 1 else { return }
        let radius = 6 + 28 * t
        let rect = CGRect(
            x: origin.x - radius,
            y: origin.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Self.palette[0].opacity(0.55 * (1 - t))),
            lineWidth: 1.4
        )
    }
}
