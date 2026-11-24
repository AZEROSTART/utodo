import AppKit
import ServiceManagement
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

        registerLoginItemIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 只在从 `~/Applications/UTodo.app` 启动时尝试注册登录项，
    /// 避免从 build/ 里跑开发版时把临时路径写进系统登录项。
    private func registerLoginItemIfNeeded() {
        let installedPath = NSHomeDirectory() + "/Applications/"
        guard Bundle.main.bundlePath.hasPrefix(installedPath) else { return }

        let key = "loginItem.attempted"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)

        let service = SMAppService.mainApp
        guard service.status == .notRegistered else { return }
        do {
            try service.register()
        } catch {
            FileHandle.standardError.write(
                Data("utodo: 登录项注册失败（可在 系统设置 → 通用 → 登录项 手动添加）：\(error)\n".utf8)
            )
        }
    }
}
