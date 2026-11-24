import CoreGraphics
import Foundation

public struct PanelPlacement: Codable, Equatable, Sendable {
    public var displayID: String
    public var offsetFromRight: CGFloat
    public var offsetFromTop: CGFloat

    public init(displayID: String, offsetFromRight: CGFloat, offsetFromTop: CGFloat) {
        self.displayID = displayID
        self.offsetFromRight = offsetFromRight
        self.offsetFromTop = offsetFromTop
    }
}

public enum PanelPosition {
    public static let defaultOffsetFromRight: CGFloat = 16
    public static let defaultOffsetFromTop: CGFloat = 24

    public static func resolve(
        _ stored: PanelPlacement?,
        panelSize: CGSize,
        screens: [(id: String, frame: CGRect)],
        mainScreenID: String
    ) -> (placement: PanelPlacement, origin: CGPoint) {
        let fallbackID = screens.first(where: { $0.id == mainScreenID })?.id ?? screens.first?.id ?? mainScreenID

        let placement: PanelPlacement
        if let stored, screens.contains(where: { $0.id == stored.displayID }) {
            placement = stored
        } else if let stored {
            placement = PanelPlacement(
                displayID: fallbackID,
                offsetFromRight: stored.offsetFromRight,
                offsetFromTop: stored.offsetFromTop
            )
        } else {
            placement = PanelPlacement(
                displayID: fallbackID,
                offsetFromRight: defaultOffsetFromRight,
                offsetFromTop: defaultOffsetFromTop
            )
        }

        let frame = screens.first(where: { $0.id == placement.displayID })?.frame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let raw = CGPoint(
            x: frame.maxX - placement.offsetFromRight - panelSize.width,
            y: frame.maxY - placement.offsetFromTop - panelSize.height
        )
        // 屏幕变小或换屏后旧偏移可能把卡片推到屏外，裁回可见范围（裁不下就贴左上）
        let origin = CGPoint(
            x: min(max(raw.x, frame.minX), max(frame.minX, frame.maxX - panelSize.width)),
            y: min(max(raw.y, frame.minY), max(frame.minY, frame.maxY - panelSize.height))
        )
        return (placement, origin)
    }

    public static func placement(
        forOrigin origin: CGPoint,
        panelSize: CGSize,
        screens: [(id: String, frame: CGRect)]
    ) -> PanelPlacement? {
        let screen = screens.min(by: {
            distance($0.frame, to: origin) < distance($1.frame, to: origin)
        })
        guard let screen else { return nil }

        return PanelPlacement(
            displayID: screen.id,
            offsetFromRight: screen.frame.maxX - origin.x - panelSize.width,
            offsetFromTop: screen.frame.maxY - origin.y - panelSize.height
        )
    }

    private static func distance(_ frame: CGRect, to point: CGPoint) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}
