import Foundation
import Testing
@testable import UTodoCore

@Suite struct TodoStoreRecoveryTests {
    @Test func corruptFileIsQuarantinedNotDeleted() throws {
        let url = tempDB()
        let garbage = Data("not a database".utf8)
        try garbage.write(to: url)

        let store = try TodoStore(url: url)
        #expect(try store.add(title: "重建")?.title == "重建")

        let siblings = try FileManager.default.contentsOfDirectory(
            at: url.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        let quarantined = siblings.filter {
            $0.lastPathComponent.hasPrefix(url.lastPathComponent + "-corrupt-")
        }
        #expect(quarantined.count == 1)
        if let first = quarantined.first {
            #expect(try Data(contentsOf: first) == garbage)
        }
    }

    @Test func headerCheckDistinguishesCorruptFromValid() throws {
        let url = tempDB()
        try Data("not a database".utf8).write(to: url)
        #expect(TodoStore.isCorrupt(at: url))

        try FileManager.default.removeItem(at: url)
        _ = try TodoStore(url: url).add(title: "正常")
        #expect(!TodoStore.isCorrupt(at: url))

        let missing = tempDB()
        #expect(!TodoStore.isCorrupt(at: missing))
    }

    @Test func deletedFileWhileOpenIsReopened() throws {
        let url = tempDB()
        let store = try TodoStore(url: url)
        _ = try store.add(title: "旧文件")

        try FileManager.default.removeItem(at: url)
        try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))

        _ = try store.add(title: "新文件")

        let reopened = try TodoStore(url: url)
        #expect(try reopened.list(includeCompleted: true).map(\.title) == ["新文件"])
    }

    @Test func replacedFileWhileOpenIsReopened() throws {
        let url = tempDB()
        let store = try TodoStore(url: url)
        _ = try store.add(title: "旧文件")

        try FileManager.default.removeItem(at: url)
        try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
        _ = try TodoStore(url: url).add(title: "别人写的")

        // 卡片再写一条，应该落在路径上真正的库里，而不是已 unlink 的 inode
        _ = try store.add(title: "我写的")

        let reopened = try TodoStore(url: url)
        #expect(try reopened.list(includeCompleted: true).map(\.title).contains("我写的"))
    }

    @Test func percentileAndUnderscoreAreNotWildcards() throws {
        let store = try TodoStore(url: tempDB())
        _ = try store.add(titles: ["买 100% 牛奶", "写周报", "a_b"])
        #expect(throws: TodoStoreError.notFound) { try store.complete(idPrefix: "ffffffff") }
        let all = try store.list(includeCompleted: true)
        #expect(all.count == 3)
    }
}
