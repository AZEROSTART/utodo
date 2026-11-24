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
