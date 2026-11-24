import Foundation
import Testing
@testable import UTodoCore

@Suite struct AppConfigTests {
    @Test func missingFileGivesDefaults() {
        let url = tempDB().appendingPathExtension("json")
        let store = ConfigStore(url: url)
        #expect(store.load() == AppConfig.default)
    }

    @Test func roundTrip() throws {
        let url = tempDB().appendingPathExtension("json")
        let store = ConfigStore(url: url)
        try store.save(AppConfig(glassOpacity: 0.6, dimAlpha: 0.4))
        #expect(store.load() == AppConfig(glassOpacity: 0.6, dimAlpha: 0.4))
    }

    @Test func partialFileKeepsOtherDefaults() throws {
        let url = tempDB().appendingPathExtension("json")
        try Data(#"{"glassOpacity":0.1}"#.utf8).write(to: url)
        let config = ConfigStore(url: url).load()
        #expect(config.glassOpacity == 0.1)
        #expect(config.dimAlpha == AppConfig.default.dimAlpha)
    }

    @Test func outOfRangeValuesAreClampedToTheRange() throws {
        let url = tempDB().appendingPathExtension("json")
        try Data(#"{"glassOpacity":5,"dimAlpha":-2}"#.utf8).write(to: url)
        let config = ConfigStore(url: url).load()
        #expect(config.glassOpacity == 1)
        #expect(config.dimAlpha == 0.05)
    }

    @Test func garbageFileGivesDefaults() throws {
        let url = tempDB().appendingPathExtension("json")
        try Data("not json".utf8).write(to: url)
        #expect(ConfigStore(url: url).load() == AppConfig.default)
    }

    @Test func savePreservesUnknownKeys() throws {
        let url = tempDB().appendingPathExtension("json")
        try Data(#"{"glassOpacity":0.3,"dimAlpha":0.55,"futureKey":"留着"}"#.utf8).write(to: url)
        let store = ConfigStore(url: url)
        try store.save(AppConfig(glassOpacity: 0.5, dimAlpha: 0.55))
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(raw?["futureKey"] as? String == "留着")
        #expect(raw?["glassOpacity"] as? Double == 0.5)
    }

    @Test func clampingHelpersHoldRanges() {
        #expect(AppConfig.glassRange == 0...1)
        #expect(AppConfig.dimRange == 0.05...1)
        #expect(AppConfig(glassOpacity: 9, dimAlpha: 0).sanitized().glassOpacity == 1)
        #expect(AppConfig(glassOpacity: -1, dimAlpha: 0).sanitized().glassOpacity == 0)
    }
}
