import CoreGraphics
import Foundation

/// 一次完整的彩纸炸开：起点、粒子 seed、开始时间
public struct FireworkBurst: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let origin: CGPoint
    public let seed: UInt64
    public let startedAt: Date

    public init(id: UUID = UUID(), origin: CGPoint, seed: UInt64, startedAt: Date) {
        self.id = id
        self.origin = origin
        self.seed = seed
        self.startedAt = startedAt
    }
}

/// 正在播放的爆点。连点完成时最多同时 3 组，超出丢最旧的
public struct BurstList: Equatable {
    public static let limit = 3
    /// 播放结束到被清掉之间的余量
    static let pruneGrace: TimeInterval = 0.15

    public private(set) var bursts: [FireworkBurst]

    public init() {
        bursts = []
    }

    public var isEmpty: Bool { bursts.isEmpty }

    public mutating func append(_ burst: FireworkBurst) {
        while bursts.count >= Self.limit {
            bursts.removeFirst()
        }
        bursts.append(burst)
    }

    public mutating func prune(at now: Date) {
        bursts.removeAll { now.timeIntervalSince($0.startedAt) >= Firework.maxLifetime + Self.pruneGrace }
    }
}
