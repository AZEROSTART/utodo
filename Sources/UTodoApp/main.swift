import AppKit

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

if CommandLine.arguments.contains("--render-preview") {
    PreviewRenderer.run()
}

let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
