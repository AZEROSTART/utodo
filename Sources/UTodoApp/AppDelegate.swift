import AppKit
import UTodoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController?
    private var model: CardViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = try? TodoStore()
        let model = CardViewModel(store: store)
        let controller = PanelController()
        controller.install(model: model)
        controller.show()

        self.model = model
        self.panelController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
