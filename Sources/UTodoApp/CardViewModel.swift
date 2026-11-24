import AppKit
import Foundation
import Observation
import UTodoCore

@MainActor
@Observable
final class CardViewModel {
    private let store: TodoStore?

    private(set) var active: [Todo] = []
    private(set) var completed: [Todo] = []
    private(set) var dissolving: [Todo] = []
    var draft: String = ""
    var showsCompleted = false
    var focusTick = 0

    init(store: TodoStore?) {
        self.store = store
        reload()
        observeChanges()
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
        guard let store else { return }
        do {
            let all = try store.list(includeCompleted: true)
            active = all.filter { !$0.isCompleted }
            completed = all.filter(\.isCompleted)
        } catch {
            active = []
            completed = []
        }
    }

    func submitDraft() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let store else { return }
        _ = try? store.add(title: title)
        draft = ""
        reload()
        postStoreChanged()
    }

    func complete(_ todo: Todo) {
        guard let store else { return }
        _ = try? store.complete(idPrefix: todo.id.uuidString)
        reload()
        postStoreChanged()
    }

    func delete(_ todo: Todo) {
        guard let store else { return }
        _ = try? store.delete(idPrefix: todo.id.uuidString)
        reload()
        postStoreChanged()
    }

    func clearCompleted() {
        guard !completed.isEmpty, let store else { return }
        dissolving = completed
        showsCompleted = false
        _ = try? store.clearCompleted()
        reload()
        postStoreChanged()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            dissolving = []
        }
    }

    func requestFocus() {
        focusTick += 1
    }

    private func observeChanges() {
        DistributedNotificationCenter.default().addObserver(
            forName: storeChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }
}
