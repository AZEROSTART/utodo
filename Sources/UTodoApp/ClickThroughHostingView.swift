import AppKit
import SwiftUI

/// 面板属于 `.accessory` App，永远不会变成「前台」窗口。默认情况下，
/// 非激活窗口的第一次点击只会激活窗口、不交给视图 —— 表现为「点一下没反应」。
/// 卡片是常驻浮层，不存在误点激活的问题，首次点击直接生效。
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
