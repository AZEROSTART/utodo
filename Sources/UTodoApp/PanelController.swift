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
    private let fullscreenMonitor = FullscreenMonitor()
    private lazy var hotKeyMonitor = HotKeyMonitor { [weak self] in
        self?.focusInput()
    }
    private weak var model: CardViewModel?
    private var isFullscreenVisible = false
    private var isHovering = false
    private var isEditing = false

    init() {
        let size = CGSize(width: Self.panelWidth, height: Self.cardHeight + Theme.panelMargin * 2)
        panel = CardPanel(
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
        dumpState("show")
        if ProcessInfo.processInfo.environment["UTODO_AUTOFOCUS"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.focusInput()
            }
        }
    }

    func focusInput() {
        // 全屏 App 在前面时也要立刻看清：不等 SwiftUI 的 focused 回调
        isEditing = true
        applyAlpha()
        panel.makeKeyAndOrderFront(nil)
        model?.requestFocus()
        dumpStateSoon("focused")
    }

    private func resignEditing() {
        isEditing = false
        applyAlpha()
        panel.makeFirstResponder(nil)
        dumpStateSoon("resigned")
    }

    private func dumpStateSoon(_ tag: String) {
        guard ProcessInfo.processInfo.environment["UTODO_DEBUG_FRAME"] != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.dumpState(tag)
        }
    }

    private func dumpState(_ tag: String) {
        guard ProcessInfo.processInfo.environment["UTODO_DEBUG_FRAME"] != nil else { return }
        let line = "\(tag) frame=\(panel.frame) alpha=\(panel.alphaValue) key=\(panel.isKeyWindow) hotkey=\(hotKeyMonitor.isRegistered)\n"
        let url = URL(fileURLWithPath: "/tmp/utodo-frame.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func install(model: CardViewModel) {
        self.model = model
        let view = DesktopCardView(
            model: model,
            onHeightChange: { [weak self] cardHeight in
                self?.resize(toCardHeight: cardHeight)
            },
            onHoverChange: { [weak self] inside in
                self?.isHovering = inside
                self?.applyAlpha()
            },
            onEditingChange: { [weak self] editing in
                self?.isEditing = editing
                self?.applyAlpha()
            }
        )
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

        fullscreenMonitor.start(panel: panel) { [weak self] isFullscreen in
            self?.isFullscreenVisible = isFullscreen
            self?.applyAlpha()
        }

        hotKeyMonitor.start()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .processIdentifier
            MainActor.assumeIsolated {
                if pid != ProcessInfo.processInfo.processIdentifier {
                    self?.resignEditing()
                }
            }
        }
        workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.resignEditing() }
        }
    }

    private func applyAlpha() {
        let dimmed = isFullscreenVisible && !isHovering && !isEditing
        let target: CGFloat = dimmed ? Theme.dimAlpha : 1.0
        guard abs(panel.alphaValue - target) > 0.01 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.dimDuration
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = target
        }
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
