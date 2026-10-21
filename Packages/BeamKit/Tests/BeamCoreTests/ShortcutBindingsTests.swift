import Foundation
import Testing
@testable import BeamCore

@Suite struct ShortcutBindingsTests {
    let tab: UInt16 = 48, space: UInt16 = 49, kKey: UInt16 = 40, qKey: UInt16 = 12, jKey: UInt16 = 38

    @Test func defaults() {
        let d = ShortcutBindings.defaults
        #expect(d.launcher == KeyCombo(keyCode: space, modifiers: .option))
        #expect(d.windowSearch == KeyCombo(keyCode: tab, modifiers: .option))
        #expect(d.switcher == KeyCombo(keyCode: tab, modifiers: .control))
        #expect(d.searchFiles == nil)
        #expect(d.settings == nil)
    }
    @Test func disabledHasNoCombos() {
        #expect(ShortcutAction.allCases.allSatisfy { ShortcutBindings.disabled[$0] == nil })
    }
    @Test func subscriptReadsAndWritesEachAction() {
        var b = ShortcutBindings.disabled
        for (i, action) in ShortcutAction.allCases.enumerated() {
            b[action] = KeyCombo(keyCode: UInt16(i), modifiers: .command)
        }
        #expect(b.launcher?.keyCode == 0)
        #expect(b.windowSearch?.keyCode == 1)
        #expect(b.switcher?.keyCode == 2)
        #expect(b.searchFiles?.keyCode == 3)
        #expect(b.settings?.keyCode == 4)
        #expect(b[.switcher] == b.switcher)
    }
    @Test func needsModifier() {
        let d = ShortcutBindings.defaults
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: kKey, modifiers: []), action: .searchFiles, in: d) == [.needsModifier])
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: kKey, modifiers: .shift), action: .searchFiles, in: d) == [.needsModifier])
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: kKey, modifiers: [.shift, .control]), action: .searchFiles, in: d) == [])
    }
    @Test func switcherUsesShift() {
        let combo = KeyCombo(keyCode: tab, modifiers: [.shift, .control])
        #expect(ShortcutValidator.issues(for: combo, action: .switcher, in: .defaults) == [.switcherUsesShift])
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: kKey, modifiers: [.shift, .control]), action: .launcher, in: .defaults) == [])
    }
    @Test func conflictNamesTheOwner() {
        let launcherCombo = ShortcutBindings.defaults.launcher!
        #expect(ShortcutValidator.issues(for: launcherCombo, action: .windowSearch, in: .defaults) == [.conflict(.launcher)])
        // Re-recording an action's own combo is no conflict.
        #expect(ShortcutValidator.issues(for: launcherCombo, action: .launcher, in: .defaults) == [])
    }
    @Test func conflictIncludesShiftVariantsWindowSearchAndSwitcherClaim() {
        // ⌥Tab window search also answers ⇧⌥Tab; ⌃Tab switcher also answers ⇧⌃Tab.
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: tab, modifiers: [.option, .shift]), action: .launcher, in: .defaults)
            == [.conflict(.windowSearch)])
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: tab, modifiers: [.control, .shift]), action: .settings, in: .defaults)
            == [.conflict(.switcher)])
    }
    @Test func systemReservedIsAWarning() {
        let cmdTab = KeyCombo(keyCode: tab, modifiers: .command), cmdSpace = KeyCombo(keyCode: space, modifiers: .command)
        #expect(ShortcutValidator.issues(for: cmdTab, action: .switcher, in: .defaults) == [.systemReserved])
        #expect(ShortcutValidator.issues(for: cmdSpace, action: .launcher, in: .defaults) == [.systemReserved])
        #expect(ShortcutValidator.issues(for: KeyCombo(keyCode: qKey, modifiers: .command), action: .settings, in: .defaults)
            == [.systemReserved])
        #expect(!ShortcutIssue.systemReserved.isBlocking)
        #expect(ShortcutIssue.needsModifier.isBlocking && ShortcutIssue.switcherUsesShift.isBlocking)
        #expect(ShortcutIssue.conflict(.launcher).isBlocking)
    }
    @Test func canClear() {
        #expect(!ShortcutValidator.canClear(.launcher, in: .defaults, menuBarIconShown: false))
        #expect(ShortcutValidator.canClear(.launcher, in: .defaults, menuBarIconShown: true))
        #expect(ShortcutValidator.canClear(.windowSearch, in: .defaults, menuBarIconShown: false))
    }
    @Test func codableRoundTrip() throws {
        var b = ShortcutBindings.defaults
        b.windowSearch = nil
        b.searchFiles = KeyCombo(keyCode: jKey, modifiers: [.command, .option])
        let data = try JSONEncoder().encode(b)
        #expect(try JSONDecoder().decode(ShortcutBindings.self, from: data) == b)
        let defaultsData = try JSONEncoder().encode(ShortcutBindings.defaults)
        #expect(try JSONDecoder().decode(ShortcutBindings.self, from: defaultsData) == .defaults)
    }
}
