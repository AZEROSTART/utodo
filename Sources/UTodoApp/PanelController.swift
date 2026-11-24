import AppKit
import SwiftUI
import UTodoCore


@MainActor
final class PanelController {
    static let cardWidth: CGFloat = 268
    static let cardHeight: CGFloat = 240
    static var panelWidth: CGFloat { cardWidth + Theme.panelMargin * 2 }

    private let panel: NSPanel
    private let placementKey = "panel.placement"
    private var installedHeight: CGFloat = 0

    init() {
        let size = CGSize(width: Self.panelWidth, height: Self.cardHeight + Theme.panelMargin * 2)
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .none
        panel.contentView = Self.placeholderView(size: size)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.savePlacement() }
        }

        placeOnScreen()
    }

    var window: NSWindow { panel }

    func show() {
        panel.orderFrontRegardless()
        if ProcessInfo.processInfo.environment["UTODO_DEBUG_FRAME"] != nil {
            for delay in [0.0, 0.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [panel] in
                    let content = panel.contentView?.frame.debugDescription ?? "nil"
                    try? "t=\(delay) frame=\(panel.frame) content=\(content)"
                        .write(toFile: "/tmp/utodo-frame.txt", atomically: true, encoding: .utf8)
                }
            }
        }
    }

    func install(model: CardViewModel) {
        let view = DesktopCardView(model: model) { [weak self] cardHeight in
            self?.resize(toCardHeight: cardHeight)
        }
        .padding(Theme.panelMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(
            x: 0,
            y: 0,
            width: Self.panelWidth,
            height: model.cardHeight + Theme.panelMargin * 2
        )
        panel.contentView = host
        resize(toCardHeight: model.cardHeight)
    }

    private func resize(toCardHeight cardHeight: CGFloat) {
        let height = cardHeight + Theme.panelMargin * 2
        guard abs(installedHeight - height) > 0.5 else { return }
        installedHeight = height

        var frame = panel.frame
        let delta = height - frame.height
        guard abs(delta) > 0.5 else { return }
        frame.size.height = height
        frame.origin.y -= delta

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }
        savePlacement()
    }

    // MARK: - 位置

    private struct ScreenRef {
        let id: String
        let frame: CGRect
    }

    private var screenRefs: [ScreenRef] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return nil }
            return ScreenRef(id: String(number.intValue), frame: screen.frame)
        }
    }

    private var mainScreenRef: ScreenRef? {
        guard let main = NSScreen.main,
              let number = main.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return screenRefs.first }
        return ScreenRef(id: String(number.intValue), frame: main.frame)
    }

    private func placeOnScreen() {
        let screens = screenRefs.map { (id: $0.id, frame: $0.frame) }
        let mainID = mainScreenRef?.id ?? screens.first?.id ?? "0"
        let resolved = PanelPosition.resolve(
            loadPlacement(),
            panelSize: panel.frame.size,
            screens: screens,
            mainScreenID: mainID
        )
        panel.setFrameOrigin(resolved.origin)
        savePlacement()
    }

    private func loadPlacement() -> PanelPlacement? {
        guard let data = UserDefaults.standard.data(forKey: placementKey) else { return nil }
        return try? JSONDecoder().decode(PanelPlacement.self, from: data)
    }

    private func savePlacement() {
        let screens = screenRefs.map { (id: $0.id, frame: $0.frame) }
        guard let placement = PanelPosition.placement(
            forOrigin: panel.frame.origin,
            panelSize: panel.frame.size,
            screens: screens
        ) else { return }
        guard let data = try? JSONEncoder().encode(placement) else { return }
        UserDefaults.standard.set(data, forKey: placementKey)
    }

    // MARK: - 占位视图

    private static func placeholderView(size: CGSize) -> NSView {
        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        view.layer?.cornerRadius = 20
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        return view
    }
}
