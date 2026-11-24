import CoreGraphics

/// 卡片上哪些位置按下并拖动会移动窗口。
/// 只放行「没有控件」的区域：顶部标题条、左右留白、底部留白。
/// 输入行要留给文本选区，行内要留给点击完成和滚动，所以中间一概不放行。
public enum CardDragZone {
    /// 顶部 12pt 内边距 + 20pt 标题条
    public static let headerHeight: CGFloat = 12 + 20
    public static let sideInset: CGFloat = 16
    public static let bottomInset: CGFloat = 12

    public static func isHandle(at point: CGPoint, cardSize: CGSize) -> Bool {
        guard point.x >= 0, point.y >= 0,
              point.x <= cardSize.width, point.y <= cardSize.height
        else { return false }

        if point.y <= headerHeight { return true }
        if point.y >= cardSize.height - bottomInset { return true }
        if point.x <= sideInset || point.x >= cardSize.width - sideInset { return true }
        return false
    }
}
