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
