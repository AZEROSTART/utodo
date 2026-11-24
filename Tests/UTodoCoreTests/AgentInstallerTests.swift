import Foundation
import Testing
@testable import UTodoCore

@Suite struct AgentInstallerTests {
    private func makeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appending(path: "utodo-home-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    @Test func installCreatesAgentsMdAndSkill() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let installer = AgentInstaller(home: home)

        let results = try installer.install()
        #expect(results.contains { $0.path == installer.agentsFile.path && $0.action == .created })
        #expect(results.contains { $0.path == installer.skillFile.path && $0.action == .created })
        // 没有 CLAUDE.md 时跳过，不新建
        #expect(results.contains { $0.path == installer.claudeFile.path && $0.action == .skipped })

        let agents = try String(contentsOf: installer.agentsFile, encoding: .utf8)
        #expect(agents.contains(AgentSkill.beginMarker))
        #expect(agents.contains("utodo add"))
        let skill = try String(contentsOf: installer.skillFile, encoding: .utf8)
        #expect(skill.hasPrefix("---\nname: utodo\n"))
    }

    @Test func installIsIdempotent() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let installer = AgentInstaller(home: home)

        _ = try installer.install()
        let first = try String(contentsOf: installer.agentsFile, encoding: .utf8)
        let second = try installer.install()
        let again = try String(contentsOf: installer.agentsFile, encoding: .utf8)

        #expect(first == again)
        #expect(second.contains { $0.path == installer.agentsFile.path && $0.action == .unchanged })
        #expect(first.components(separatedBy: AgentSkill.beginMarker).count == 2)
    }

    @Test func installKeepsExistingContentAndUpdatesStaleBlock() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appending(path: ".claude"), withIntermediateDirectories: true)
        try "我自己的规则\n".write(to: home.appending(path: "AGENTS.md"), atomically: true, encoding: .utf8)

        let installer = AgentInstaller(home: home)
        _ = try installer.install()
        var text = try String(contentsOf: installer.agentsFile, encoding: .utf8)
        #expect(text.hasPrefix("我自己的规则\n"))
        #expect(text.contains(AgentSkill.beginMarker))

        // 块里的内容被改脏后重跑，只换块内内容
        text = text.replacingOccurrences(of: "utodo add", with: "被人改坏了")
        try text.write(to: installer.agentsFile, atomically: true, encoding: .utf8)
        let results = try installer.install()
        #expect(results.contains { $0.path == installer.agentsFile.path && $0.action == .updated })
        let repaired = try String(contentsOf: installer.agentsFile, encoding: .utf8)
        #expect(repaired.hasPrefix("我自己的规则\n"))
        #expect(repaired.contains("utodo add"))
        #expect(!repaired.contains("被人改坏了"))
    }

    @Test func uninstallRemovesOnlyOurBlock() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try "我自己的规则\n".write(to: home.appending(path: "AGENTS.md"), atomically: true, encoding: .utf8)
        let installer = AgentInstaller(home: home)
        _ = try installer.install()

        _ = try installer.uninstall()
        let text = try String(contentsOf: installer.agentsFile, encoding: .utf8)
        #expect(text == "我自己的规则\n")
        #expect(!FileManager.default.fileExists(atPath: installer.skillFile.path))
    }

    @Test func symlinkedClaudeFileIsSkipped() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appending(path: ".claude"), withIntermediateDirectories: true)
        let shared = home.appending(path: "shared-instructions.md")
        try "共享规则\n".write(to: shared, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: home.appending(path: ".claude/CLAUDE.md"),
            withDestinationURL: shared
        )

        let installer = AgentInstaller(home: home)
        let results = try installer.install()
        #expect(results.contains { $0.path == installer.claudeFile.path && $0.action == .skipped })
        // 软链和它的目标都没被写
        #expect(try String(contentsOf: shared, encoding: .utf8) == "共享规则\n")
    }

    @Test func embeddedSkillMatchesRepositoryFile() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // UTodoCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // 仓库根
        let onDisk = try String(contentsOf: repo.appending(path: "Skill/SKILL.md"), encoding: .utf8)
        let normalized = onDisk.hasSuffix("\n") ? String(onDisk.dropLast()) : onDisk
        #expect(AgentSkill.text == normalized)
    }
}
