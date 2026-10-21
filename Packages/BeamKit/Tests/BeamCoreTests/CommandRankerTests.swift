import Testing
@testable import BeamCore

@Suite struct CommandRankerTests {
    let settings = ["Beam Settings", "Settings", "Preferences"]
    let switchWindows = ["Switch Windows", "Windows"]

    @Test func settingsQueryPutsBeamSettingsAboveSystemSettings() {
        let command = CommandRanker.match("settings", names: settings)!
        let app = CommandRanker.match("settings", names: ["System Settings"])
        #expect(CommandRanker.outranksApps(command, bestApp: app))
    }
    @Test func partialAliasStillWins() {
        let command = CommandRanker.match("sett", names: settings)!
        #expect(CommandRanker.outranksApps(command, bestApp: CommandRanker.match("sett", names: ["System Settings"])))
    }
    @Test func singleLetterKeepsAppsFirst() {
        let command = CommandRanker.match("s", names: switchWindows)!
        #expect(!CommandRanker.outranksApps(command, bestApp: CommandRanker.match("s", names: ["Safari"])))
    }
    @Test func exactAppNameKeepsAppFirst() {
        let command = CommandRanker.match("system settings", names: settings)
        let app = CommandRanker.match("system settings", names: ["System Settings"])
        #expect(command.map { !CommandRanker.outranksApps($0, bestApp: app) } ?? true)
    }
    @Test func commandWithNoMatchingAppIsPromoted() {
        let command = CommandRanker.match("pref", names: settings)!
        #expect(CommandRanker.outranksApps(command, bestApp: nil))
    }
    @Test func bestOfSeveralNamesIsUsed() {
        #expect(CommandRanker.match("preferences", names: settings)?.tier == .exact)
        #expect(CommandRanker.match("xyz", names: settings) == nil)
    }
}
