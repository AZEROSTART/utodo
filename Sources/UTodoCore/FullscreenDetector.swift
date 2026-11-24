import CoreGraphics
import Foundation

public struct WindowSnapshot: Equatable, Sendable {
    public var ownerPID: pid_t
    public var bounds: CGRect

    public init(ownerPID: pid_t, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.bounds = bounds
    }
}

public enum FullscreenDetector {
    public static func isFullscreen(
        frontPID: pid_t,
        windows: [WindowSnapshot],
        screenFrame: CGRect,
        tolerance: CGFloat = 2
    ) -> Bool {
        windows.contains { window in
            guard window.ownerPID == frontPID else { return false }
            return abs(window.bounds.minX - screenFrame.minX) <= tolerance
                && abs(window.bounds.minY - screenFrame.minY) <= tolerance
                && abs(window.bounds.maxX - screenFrame.maxX) <= tolerance
                && abs(window.bounds.maxY - screenFrame.maxY) <= tolerance
        }
    }
}
