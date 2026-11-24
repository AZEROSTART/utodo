import AppKit
import Foundation
import Observation
import UTodoCore

@MainActor
@Observable
final class CardViewModel {
    private let store: TodoStore?
    private let configStore: ConfigStore
    @ObservationIgnored nonisolated(unsafe) private var observerToken: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var configToken: NSObjectProtocol?

    private(set) var active: [Todo] = []
    private(set) var completed: [Todo] = []
    private(set) var dissolving: [Todo] = []
    private(set) var bursts = BurstList()
    private(set) var loadError: String?
    private(set) var config: AppConfig
    var draft: String = ""
    var showsCompleted = false
    var focusTick = 0

    init(store: TodoStore?, initialError: String? = nil, configStore: ConfigStore = ConfigStore()) {
        self.store = store
        self.configStore = configStore
        self.config = configStore.load()
        self.loadError = initialError
        if store != nil { reload() }
        observeChanges()
    }

    deinit {
        if let observerToken {
            DistributedNotificationCenter.default().removeObserver(observerToken)
        }
        if let configToken {
            DistributedNotificationCenter.default().removeObserver(configToken)
        }
    }

    var visibleActive: [Todo] { Array(active.prefix(Theme.maxVisibleRows)) }
    var completedCount: Int { completed.count }
    var isScrolling: Bool { active.count > Theme.maxVisibleRows }

    var cardHeight: CGFloat {
        var height: CGFloat = 12 + 20 + 6 + 28 + 2
        if active.isEmpty {
            height += 34
        } else {
            height += CGFloat(min(active.count, Theme.maxVisibleRows)) * Theme.rowHeight
        }
        if !completed.isEmpty { height += 26 }
        if showsCompleted {
            height += CGFloat(min(completed.count, Theme.maxVisibleRows)) * Theme.rowHeight + 4
        }
        if !dissolving.isEmpty {
            height += CGFloat(min(dissolving.count, Theme.maxVisibleRows)) * Theme.rowHeight + 4
        }
        height += 10
        return height
    }

    func reload() {
        guard let store else {
            loadError = "数据库打不开，待办写不进去"
            return
        }
        do {
            let all = try store.list(includeCompleted: true)
            active = all.filter { !$0.isCompleted }
            completed = all.filter(\.isCompleted)
            loadError = nil
        } catch {
            loadError = "读库失败：\(describe(error))"
        }
    }

    func submitDraft() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard let store else {
            loadError = "数据库打不开，这条没存上"
            return
        }
        do {
            _ = try store.add(title: title)
            draft = ""
            reload()
            postStoreChanged()
        } catch {
            loadError = "没存上：\(describe(error))"
        }
    }

    func complete(_ todo: Todo, burstAt origin: CGPoint?) {
        guard let store else { return }
        do {
            _ = try store.complete(idPrefix: todo.id.uuidString)
            reload()
            if let origin { addBurst(at: origin) }
            postStoreChanged()
        } catch {
            loadError = "没标上完成：\(describe(error))"
        }
    }

    /// 记一次彩纸爆点。最多同时 3 组（由 BurstList 丢最旧），到点自动清掉
    func addBurst(at origin: CGPoint, startedAt: Date = Date()) {
        // 完成最后一行会立刻让卡片变矮，夹回可见区，别让烟花在裁剪线外炸
        let clamped = Firework.clampOrigin(
            origin,
            cardSize: CGSize(width: Theme.cardWidth, height: cardHeight)
        )
        bursts.append(FireworkBurst(origin: clamped, seed: .random(in: 0..<UInt64.max), startedAt: startedAt))
        let wait = max(0, startedAt.addingTimeInterval(Firework.maxLifetime + 0.2).timeIntervalSinceNow)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            bursts.prune(at: Date())
        }
    }

    func delete(_ todo: Todo) {
        guard let store else { return }
        do {
            _ = try store.delete(idPrefix: todo.id.uuidString)
            reload()
            postStoreChanged()
        } catch {
            loadError = "没删掉：\(describe(error))"
        }
    }

    func clearCompleted() {
        guard !completed.isEmpty, let store else { return }
        dissolving = completed
        showsCompleted = false
        do {
            _ = try store.clearCompleted()
            reload()
            postStoreChanged()
        } catch {
            dissolving = []
            loadError = "没清掉：\(describe(error))"
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            dissolving = []
        }
    }

    private func describe(_ error: Error) -> String {
        if case let TodoStoreError.database(message) = error { return message }
        return "\(error)"
    }

    func requestFocus() {
        focusTick += 1
    }

    /// 右键菜单改玻璃底色：写配置 → 发通知 → 自己和别的窗口都读一次
    func setGlassOpacity(_ value: Double) {
        var updated = config
        updated.glassOpacity = value
        do {
            try configStore.save(updated)
        } catch {
            loadError = "透明度没存上：\(error)"
            return
        }
        config = configStore.load()
        postConfigChanged()
    }

    private func observeChanges() {
        observerToken = DistributedNotificationCenter.default().addObserver(
            forName: storeChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }

        configToken = DistributedNotificationCenter.default().addObserver(
            forName: configChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.config = self?.configStore.load() ?? .default }
        }
    }
}
