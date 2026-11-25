import SwiftUI

enum Theme {
    static let cardWidth: CGFloat = 268
    static let corner: CGFloat = 20
    static let bodySize: CGFloat = 12.5
    static let rowHeight: CGFloat = 30
    static let maxVisibleRows = 5
    static let panelMargin: CGFloat = 36
    static let dimDuration: CGFloat = 0.3

    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.55)
    static let faintText = Color.white.opacity(0.40)
    static let placeholderText = Color.white.opacity(0.42)
    static let hairline = Color.white.opacity(0.065)

    static let accent = Color(hue: 0.56, saturation: 0.55, brightness: 1.0)
}
