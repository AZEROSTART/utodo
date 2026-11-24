import CoreGraphics
import Foundation
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
