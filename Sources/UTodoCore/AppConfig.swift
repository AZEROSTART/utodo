import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var glassOpacity: Double
    public var dimAlpha: Double

    /// 玻璃底色不透明度：0 只剩材质，1 接近实心
    public static let glassRange: ClosedRange<Double> = 0...1
    /// 全屏退让时整窗 alpha
    public static let dimRange: ClosedRange<Double> = 0.05...1

    public static let `default` = AppConfig(glassOpacity: 0.30, dimAlpha: 0.55)

    public init(glassOpacity: Double = 0.30, dimAlpha: Double = 0.55) {
        self.glassOpacity = glassOpacity
        self.dimAlpha = dimAlpha
    }

    /// 手改出来的越界值夹回合法区间（5 表示「想更实」），NaN 才回落默认值
    public func sanitized() -> AppConfig {
        AppConfig(
            glassOpacity: Self.clamp(glassOpacity, to: Self.glassRange) ?? Self.default.glassOpacity,
            dimAlpha: Self.clamp(dimAlpha, to: Self.dimRange) ?? Self.default.dimAlpha
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double? {
        guard value.isFinite else { return nil }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

public let configChangedNotification = Notification.Name("com.azerostart.utodo.configChanged")

public func postConfigChanged() {
    DistributedNotificationCenter.default().post(name: configChangedNotification, object: nil)
}

public final class ConfigStore: @unchecked Sendable {
    public static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment["UTODO_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "utodo", directoryHint: .isDirectory)
            .appending(path: "config.json", directoryHint: .notDirectory)
    }

    private let url: URL
    private let lock = NSLock()

    public init(url: URL = ConfigStore.defaultURL) {
        self.url = url
    }

    public func load() -> AppConfig {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .default }

        var config = AppConfig.default
        if let glass = raw["glassOpacity"] as? Double {
            config.glassOpacity = glass
        }
        if let dim = raw["dimAlpha"] as? Double {
            config.dimAlpha = dim
        }
        return config.sanitized()
    }

    /// 原子写：临时文件 + rename；未知键原样保留，不吞掉别人的配置
    public func save(_ config: AppConfig) throws {
        lock.lock()
        defer { lock.unlock() }

        let clean = config.sanitized()
        var raw: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            raw = existing
        }
        raw["glassOpacity"] = clean.glassOpacity
        raw["dimAlpha"] = clean.dimAlpha

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: raw,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        let temporary = directory.appending(path: ".config-\(UUID().uuidString).json")
        try data.write(to: temporary)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }
}
