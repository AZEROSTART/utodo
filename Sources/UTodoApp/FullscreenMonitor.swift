import AppKit
import CoreGraphics
import UTodoCore

@MainActor
final class FullscreenMonitor {
    private var timer: Timer?
    private var lastValue: Bool?
    private var onChange: ((Bool) -> Void)?
    private weak var panel: NSWindow?

    func start(panel: NSWindow, onChange: @escaping (Bool) -> Void) {
        self.panel = panel
        self.onChange = onChange

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }

        evaluate()
    }

    private func evaluate() {
        guard let panel, let screen = panel.screen else { return }
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontPID != ProcessInfo.processInfo.processIdentifier
        else {
            publish(false)
            return
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let screenFrame = screen.frame
        let cgScreenFrame = CGRect(
            x: screenFrame.minX,
            y: primaryHeight - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height
        )

        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let snapshots: [WindowSnapshot] = info.compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let dict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict as CFDictionary)
            else { return nil }
            return WindowSnapshot(ownerPID: pid, bounds: rect)
        }

        publish(FullscreenDetector.isFullscreen(
            frontPID: frontPID,
            windows: snapshots,
            screenFrame: cgScreenFrame
        ))
    }

    private func publish(_ value: Bool) {
        guard value != lastValue else { return }
        lastValue = value
        onChange?(value)
    }
}
