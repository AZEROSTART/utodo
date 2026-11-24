import AppKit
import SwiftUI
import UTodoCore

@MainActor
enum PreviewRenderer {
    static func run() {
        let url = FileManager.default.temporaryDirectory.appending(path: "utodo-preview.sqlite3")
        try? FileManager.default.removeItem(at: url)
        let store = try? TodoStore(url: url)
        _ = try? store?.add(titles: [
            "回 Alice 关于合同 b 款的修改",
            "把全屏层级的坑查清楚",
            "18:30 前交季度报表",
            "修滚动条在小窗下的截断",
            "预约牙医",
            "把设计文档补完",
        ])
        if let todos = try? store?.list(includeCompleted: false), let oldest = todos.last {
            _ = try? store?.complete(idPrefix: oldest.id.uuidString)
        }

        let model = CardViewModel(store: store)
        model.showsCompleted = true

        let desktop = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.15, blue: 0.32),
                    Color(red: 0.11, green: 0.19, blue: 0.27),
                    Color(red: 0.30, green: 0.18, blue: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack {
                HStack {
                    Spacer()
                    DesktopCardView(model: model, onHeightChange: { _ in }, isPreview: true)
                }
                Spacer()
            }
            .padding(24)
        }
        .frame(width: Theme.cardWidth + Theme.panelMargin * 2 + 48, height: 460)

        let renderer = ImageRenderer(content: desktop)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("preview render failed\n".utf8))
            exit(1)
        }
        let arguments = CommandLine.arguments
        var out = URL(fileURLWithPath: "/tmp/utodo-preview.png")
        if let index = arguments.firstIndex(of: "--render-preview"), arguments.count > index + 1 {
            out = URL(fileURLWithPath: arguments[index + 1])
        }
        try? png.write(to: out)
        print("preview: \(out.path)")
        exit(0)
    }
}
