import CoreGraphics
import Foundation

public struct WindowSnapshot: Equatable, Sendable {
    public var ownerPID: pid_t
    public var bounds: CGRect
    public var layer: Int32

    public init(ownerPID: pid_t, bounds: CGRect, layer: Int32 = 0) {
        self.ownerPID = ownerPID
        self.bounds = bounds
        self.layer = layer
    }
}

public enum FullscreenDetector {
    /// 只有普通应用窗口（layer 0）才算数：菜单栏、Dock、壁纸、WindowServer
    /// 都有全屏尺寸但层级是负数或系统层级，不能当作前台 App 的全屏窗口。
    public static func isFullscreen(
        frontPID: pid_t,
        windows: [WindowSnapshot],
        screenFrame: CGRect,
        tolerance: CGFloat = 2
    ) -> Bool {
        windows.contains { window in
            guard window.ownerPID == frontPID, window.layer == 0 else { return false }
            return abs(window.bounds.minX - screenFrame.minX) <= tolerance
                && abs(window.bounds.minY - screenFrame.minY) <= tolerance
                && abs(window.bounds.maxX - screenFrame.maxX) <= tolerance
                && abs(window.bounds.maxY - screenFrame.maxY) <= tolerance
        }
    }
}
