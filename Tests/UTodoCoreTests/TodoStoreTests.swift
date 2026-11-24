import Foundation
import Testing
@testable import UTodoCore

func tempDB() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "utodo-\(UUID().uuidString).sqlite3")
}

@Suite struct TodoStoreTests {
    @Test func addTrimsTitle() throws {
        let store = try TodoStore(url: tempDB())
        let todo = try store.add(title: "  买牛奶  ")
        #expect(todo?.title == "买牛奶")
        #expect(try store.list(includeCompleted: true).count == 1)
    }

    @Test func blankTitleIsIgnored() throws {
        let store = try TodoStore(url: tempDB())
        #expect(try store.add(title: "   ") == nil)
        #expect(try store.add(titles: ["", "  ", "写周报"]).map(\.title) == ["写周报"])
    }

    @Test func activeListIsNewestFirstThenCompleted() throws {
        let store = try TodoStore(url: tempDB())
        let first = try store.add(title: "第一")!
        let second = try store.add(title: "第二")!
        _ = try store.complete(idPrefix: shortID(first))
        let titles = try store.list(includeCompleted: true).map(\.title)
        #expect(titles == ["第二", "第一"])
        #expect(try store.list(includeCompleted: false).map(\.title) == ["第二"])
    }

    @Test func completeIsIdempotentAndPrefixMatches() throws {
        let store = try TodoStore(url: tempDB())
        let todo = try store.add(title: "甲")!
        let once = try store.complete(idPrefix: shortID(todo))
        let twice = try store.complete(idPrefix: shortID(todo))
        #expect(once.completedAt == twice.completedAt)
        #expect(twice.id == todo.id)
    }

    @Test func unknownPrefixThrowsNotFound() throws {
        let store = try TodoStore(url: tempDB())
        #expect(throws: TodoStoreError.notFound) { try store.complete(idPrefix: "ffffffff") }
    }

    @Test func clearCompletedReturnsCountAndKeepsActive() throws {
        let store = try TodoStore(url: tempDB())
        let a = try store.add(title: "甲")!
        _ = try store.add(title: "乙")
        _ = try store.complete(idPrefix: shortID(a))
        #expect(try store.clearCompleted() == 1)
        #expect(try store.list(includeCompleted: true).map(\.title) == ["乙"])
    }

    @Test func dataSurvivesReopen() throws {
        let url = tempDB()
        _ = try TodoStore(url: url).add(title: "活着")
        #expect(try TodoStore(url: url).list(includeCompleted: true).map(\.title) == ["活着"])
    }

    @Test func brokenFileIsRebuiltNotFatal() throws {
        let url = tempDB()
        try Data("not a database".utf8).write(to: url)
        let store = try TodoStore(url: url)
        #expect(try store.add(title: "重建") != nil)
    }
}

func shortID(_ todo: Todo) -> String { String(todo.id.uuidString.prefix(8)).lowercased() }
