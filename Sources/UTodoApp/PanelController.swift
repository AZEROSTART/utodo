import AppKit
import UTodoCore


@MainActor
final class PanelController {
    static let cardWidth: CGFloat = 268
    static let cardHeight: CGFloat = 240

    private let panel: NSPanel
    private let placementKey = "panel.placement"

    init() {
        let size = CGSize(width: Self.cardWidth, height: Self.cardHeight)
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
    }

    func setContent(_ view: NSView) {
        panel.contentView = view
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
