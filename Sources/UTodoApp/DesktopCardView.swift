import SwiftUI
import UTodoCore

struct GlassBackground: View {
    var opacity: Double = AppConfig.default.glassOpacity

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color.black.opacity(opacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.20),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.42), radius: 22, x: 0, y: 12)
            .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
    }
}

struct DesktopCardView: View {
    @Bindable var model: CardViewModel
    var onHeightChange: (CGFloat) -> Void
    var onHoverChange: (Bool) -> Void = { _ in }
    var onEditingChange: (Bool) -> Void = { _ in }
    var onRequestFocus: () -> Void = {}
    var onEndEditing: () -> Void = {}
    var isPreview: Bool = false

    @FocusState private var inputFocused: Bool
    @State private var hoveringRow: UUID?
    @State private var dissolveProgress: CGFloat = 0

    /// 右键菜单里的三档玻璃底色；CLI 可以填任意值，菜单只负责常用档位
    static let glassPresets: [(name: String, value: Double)] = [
        ("通透", 0.12),
        ("标准", 0.30),
        ("实心", 0.55),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            inputRow
            activeRows
            completedFooter
            if model.showsCompleted { completedRows }
            if !model.dissolving.isEmpty { dissolvingRows }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: Theme.cardWidth, alignment: .top)
        .background(GlassBackground(opacity: model.config.glassOpacity))
        .contentShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .contextMenu {
            Button("添加一件事") { onRequestFocus() }
            Menu("透明度") {
                ForEach(Self.glassPresets, id: \.value) { preset in
                    Button {
                        model.setGlassOpacity(preset.value)
                    } label: {
                        if abs(model.config.glassOpacity - preset.value) < 0.005 {
                            Label(preset.name, systemImage: "checkmark")
                        } else {
                            Text(preset.name)
                        }
                    }
                }
            }
            Button(model.showsCompleted ? "收起已完成" : "显示已完成") {
                withAnimation(.easeInOut(duration: 0.2)) { model.showsCompleted.toggle() }
            }
            .disabled(model.completedCount == 0)
            Button("清除已完成") { model.clearCompleted() }
                .disabled(model.completedCount == 0)
            Divider()
            Button("退出 utodo") { NSApp.terminate(nil) }
        }
        .animation(.easeOut(duration: 0.18), value: model.active)
        .onChange(of: model.cardHeight) { _, height in onHeightChange(height) }
        .onAppear { onHeightChange(model.cardHeight) }
        .onChange(of: model.focusTick) { _, _ in inputFocused = true }
        .onChange(of: inputFocused) { _, focused in onEditingChange(focused) }
        .onHover { inside in onHoverChange(inside) }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("今天")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(Color.white.opacity(0.60))
            Spacer(minLength: 0)
            Text("\(model.active.count)")
                .font(.system(size: 11, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .padding(.horizontal, 2)
        .frame(height: 20)
    }

    // MARK: - 输入行

    private var inputRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
            if isPreview {
                Text("添加一件事…")
                    .font(.system(size: Theme.bodySize))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("添加一件事…", text: $model.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.bodySize))
                    .foregroundStyle(Theme.primaryText)
                    .focused($inputFocused)
                    .onSubmit { model.submitDraft() }
                    .onKeyPress(.escape) {
                        inputFocused = false
                        onEndEditing()
                        return .handled
                    }
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.085))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        )
        .padding(.top, 6)
        .padding(.bottom, 2)
        .onTapGesture { onRequestFocus() }
        .contentShape(Rectangle())
    }

    // MARK: - 未完成

    private var activeRows: some View {
        Group {
            if model.active.isEmpty {
                Text(model.loadError ?? "都清空了。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(model.loadError == nil ? Theme.faintText : Color.orange.opacity(0.85))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 4)
            } else if model.isScrolling && !isPreview {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.active) { row($0) }
                    }
                }
                .frame(height: CGFloat(Theme.maxVisibleRows) * Theme.rowHeight)
                .scrollIndicators(.never)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.visibleActive) { row($0) }
                }
            }
        }
    }

    private func row(_ todo: Todo) -> some View {
        HStack(spacing: 9) {
            Button { model.complete(todo) } label: {
                Circle()
                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 1.2)
                    .frame(width: 16, height: 16)
                    // 描边形状只在外圈命中，补一块实心命中区，点圆心才算点到
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("完成")

            Text(todo.title)
                .font(.system(size: Theme.bodySize))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .contentShape(Rectangle())
                .onTapGesture { model.complete(todo) }

            Spacer(minLength: 0)

            if hoveringRow == todo.id {
                HStack(spacing: 8) {
                    Button { model.delete(todo) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: Theme.rowHeight)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .opacity(indexIsFirst(todo) ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onHover { inside in hoveringRow = inside ? todo.id : nil }
    }

    private func indexIsFirst(_ todo: Todo) -> Bool {
        model.active.first?.id == todo.id
    }

    // MARK: - 已完成

    private var completedFooter: some View {
        Group {
            if model.completedCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { model.showsCompleted.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text("\(model.completedCount) 已完成")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.faintText)
                        Image(systemName: model.showsCompleted ? "chevron.up" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.30))
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .frame(height: 26)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
            }
        }
    }

    private var completedRows: some View {
        Group {
            if model.completed.count > Theme.maxVisibleRows && !isPreview {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.completed) { todo in
                            completedRow(todo, interactive: true)
                        }
                    }
                }
                .frame(height: CGFloat(Theme.maxVisibleRows) * Theme.rowHeight)
                .scrollIndicators(.never)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.completed.prefix(Theme.maxVisibleRows)) { todo in
                        completedRow(todo, interactive: true)
                    }
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - 清除特效

    private var dissolvingRows: some View {
        VStack(spacing: 0) {
            ForEach(model.dissolving.prefix(Theme.maxVisibleRows)) { todo in
                completedRow(todo, interactive: false)
                    .offset(y: -9 * dissolveProgress)
                    .opacity(1 - dissolveProgress)
                    .blur(radius: 1.6 * dissolveProgress)
            }
        }
        .onAppear { startDissolve() }
        .onChange(of: model.dissolving) { _, rows in
            if !rows.isEmpty { startDissolve() }
        }
    }

    private func startDissolve() {
        dissolveProgress = 0
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.35)) { dissolveProgress = 1 }
        }
    }

    private func completedRow(_ todo: Todo, interactive: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.28))
            Text(todo.title)
                .font(.system(size: Theme.bodySize))
                .foregroundStyle(Color.white.opacity(0.40))
                .strikethrough(color: Color.white.opacity(0.30))
                .lineLimit(1)
            Spacer(minLength: 0)
            if interactive, hoveringRow == todo.id {
                Button { model.delete(todo) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: Theme.rowHeight)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            guard interactive else { return }
            hoveringRow = inside ? todo.id : nil
        }
    }
}
