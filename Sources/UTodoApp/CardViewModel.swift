import AppKit
import Foundation
import Observation
import UTodoCore

@MainActor
@Observable
final class CardViewModel {
    private let store: TodoStore?
    @ObservationIgnored nonisolated(unsafe) private var observerToken: NSObjectProtocol?

    private(set) var active: [Todo] = []
    private(set) var completed: [Todo] = []
    private(set) var dissolving: [Todo] = []
    private(set) var loadError: String?
    var draft: String = ""
    var showsCompleted = false
    var focusTick = 0

    init(store: TodoStore?, initialError: String? = nil) {
        self.store = store
        self.loadError = initialError
        if store != nil { reload() }
        observeChanges()
    }

    deinit {
        if let observerToken {
            DistributedNotificationCenter.default().removeObserver(observerToken)
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

    func complete(_ todo: Todo) {
        guard let store else { return }
        do {
            _ = try store.complete(idPrefix: todo.id.uuidString)
            reload()
            postStoreChanged()
        } catch {
            loadError = "没标上完成：\(describe(error))"
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

    private func observeChanges() {
        observerToken = DistributedNotificationCenter.default().addObserver(
            forName: storeChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }
}
