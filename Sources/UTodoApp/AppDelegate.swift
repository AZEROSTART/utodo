import AppKit


@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PanelController()
        controller.show()
        panelController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
