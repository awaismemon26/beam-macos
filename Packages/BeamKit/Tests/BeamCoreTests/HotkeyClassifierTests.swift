import Foundation
import Testing
@testable import BeamCore

@Suite struct HotkeyClassifierTests {
    let tab: UInt16 = 48, ret: UInt16 = 36, keypadEnter: UInt16 = 76, esc: UInt16 = 53, space: UInt16 = 49, aKey: UInt16 = 0

    func down(_ k: UInt16, _ m: KeyModifiers, repeat r: Bool = false) -> RawKeyEvent { .keyDown(keyCode: k, modifiers: m, isRepeat: r) }

    @Test func ctrlTabOpensSwitcher() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(tab, [.control])) == .switcher(.tab(shift: false)))
    }
    @Test func ctrlShiftTabIsShiftTab() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(tab, [.control, .shift])) == .switcher(.tab(shift: true)))
    }
    @Test func optionTabOpensWindowSearch() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(tab, [.option])) == .openWindowSearch)
    }
    @Test func cmdTabPasses() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(tab, [.command])) == .pass)
    }
    @Test func ctrlOptionTabPasses() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(tab, [.control, .option])) == .pass)
    }
    @Test func optionSpaceTogglesRoot() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(space, [.option])) == .toggleRootSearch)
    }
    @Test func customRootComboHonoured() {
        var b = ShortcutBindings.defaults; b.launcher = KeyCombo(keyCode: 49, modifiers: [.command])
        var c = HotkeyClassifier(bindings: b)
        #expect(c.classify(down(space, [.command])) == .toggleRootSearch)
        #expect(c.classify(down(space, [.option])) == .pass)
    }
    @Test func optionSpaceRepeatIsSwallowed() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(space, [.option], repeat: true)) == .swallow)
    }
    @Test func returnWhileOpenIsEnter() {
        var c = HotkeyClassifier(); c.isSwitcherOpen = true
        #expect(c.classify(down(ret, [.control])) == .switcher(.enter))
    }
    @Test func keypadEnterWhileOpenIsEnter() {
        var c = HotkeyClassifier(); c.isSwitcherOpen = true
        #expect(c.classify(down(keypadEnter, [.control])) == .switcher(.enter))
    }
    @Test func escapeWhileOpen() {
        var c = HotkeyClassifier(); c.isSwitcherOpen = true
        #expect(c.classify(down(esc, [.control])) == .switcher(.escape))
    }
    @Test func otherKeyWhileOpenIsSwallowed() {
        var c = HotkeyClassifier(); c.isSwitcherOpen = true
        #expect(c.classify(down(aKey, [.control])) == .swallow)
    }
    @Test func returnWhileClosedPasses() {
        var c = HotkeyClassifier()
        #expect(c.classify(down(ret, [])) == .pass)
    }
    @Test func controlReleaseWhileOpen() {
        var c = HotkeyClassifier(); c.isSwitcherOpen = true
        #expect(c.classify(.flagsChanged(modifiers: [])) == .switcher(.controlReleased))
    }
    @Test func controlReleaseWhileClosedPasses() {
        var c = HotkeyClassifier()
        #expect(c.classify(.flagsChanged(modifiers: [])) == .pass)
    }
    @Test func keyUpForSwallowedKeyDownIsSwallowedEvenAfterModifierRelease() {
        var c = HotkeyClassifier()
        _ = c.classify(down(tab, [.control]))
        #expect(c.classify(.keyUp(keyCode: tab, modifiers: [])) == .swallow)
        #expect(c.classify(.keyUp(keyCode: tab, modifiers: [])) == .pass)
    }
    @Test func tapDisabledEventRequestsReenable() {
        var c = HotkeyClassifier()
        #expect(c.classify(.tapDisabled) == .reenableTap)
    }
    @Test func keyComboRoundTripsThroughCodable() throws {
        let combo = KeyCombo(keyCode: space, modifiers: .option)
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
    }

    @Test func ctrlTabMarksSwitcherOpenImmediately() {
        var c = HotkeyClassifier()
        _ = c.classify(down(tab, [.control]))
        #expect(c.isSwitcherOpen)
        #expect(c.classify(.flagsChanged(modifiers: [])) == .switcher(.controlReleased))
    }
    @Test func controlReleaseMarksSwitcherClosed() {
        var c = HotkeyClassifier()
        _ = c.classify(down(tab, [.control]))
        _ = c.classify(.flagsChanged(modifiers: []))
        #expect(!c.isSwitcherOpen)
        #expect(c.classify(.flagsChanged(modifiers: [])) == .pass)
    }
    @Test func escapeMarksSwitcherClosed() {
        var c = HotkeyClassifier()
        _ = c.classify(down(tab, [.control]))
        _ = c.classify(down(esc, [.control]))
        #expect(!c.isSwitcherOpen)
    }

    @Test func keyDownWithoutControlWhileOpenClosesAndPasses() {
        // Control was released while the tap was disabled, so its flagsChanged never arrived.
        var c = HotkeyClassifier()
        _ = c.classify(down(tab, [.control]))
        #expect(c.classify(down(aKey, [])) == .switcher(.controlReleased))
        #expect(!c.isSwitcherOpen)
        #expect(c.classify(.keyUp(keyCode: aKey, modifiers: [])) == .pass)
    }
    @Test func staleSwallowedKeyUpDoesNotEatNextKeyUp() {
        // Tab's keyUp was lost while the tap was disabled; the next ordinary Tab must reach the app whole.
        var c = HotkeyClassifier()
        _ = c.classify(down(tab, [.control]))
        _ = c.classify(.tapDisabled)
        _ = c.classify(.flagsChanged(modifiers: []))
        #expect(c.classify(down(tab, [])) == .pass)
        #expect(c.classify(.keyUp(keyCode: tab, modifiers: [])) == .pass)
    }

    // MARK: Custom bindings

    let jKey: UInt16 = 38, backtick: UInt16 = 50, fKey: UInt16 = 3, comma: UInt16 = 43

    @Test func customWindowSearchCombo() {
        var b = ShortcutBindings.defaults; b.windowSearch = KeyCombo(keyCode: jKey, modifiers: .command)
        var c = HotkeyClassifier(bindings: b)
        #expect(c.classify(down(jKey, [.command])) == .openWindowSearch)
        #expect(c.classify(down(jKey, [.command, .shift])) == .openWindowSearch)
        #expect(c.classify(down(tab, [.option])) == .pass)
    }
    @Test func customSwitcherCombo() {
        var b = ShortcutBindings.defaults; b.switcher = KeyCombo(keyCode: backtick, modifiers: .option)
        var c = HotkeyClassifier(bindings: b)
        #expect(c.classify(down(tab, [.control])) == .pass)
        #expect(c.classify(down(backtick, [.option])) == .switcher(.tab(shift: false)))
        #expect(c.classify(down(backtick, [.option, .shift])) == .switcher(.tab(shift: true)))
        #expect(c.classify(down(ret, [.option])) == .switcher(.enter))
        #expect(c.classify(.flagsChanged(modifiers: [])) == .switcher(.controlReleased))
        #expect(!c.isSwitcherOpen)
    }
    @Test func customSwitcherClosesOnKeyDownWithoutItsModifier() {
        var b = ShortcutBindings.defaults; b.switcher = KeyCombo(keyCode: backtick, modifiers: .option)
        var c = HotkeyClassifier(bindings: b)
        _ = c.classify(down(backtick, [.option]))
        #expect(c.classify(down(aKey, [.control])) == .switcher(.controlReleased))
    }
    @Test func multiModifierSwitcherReleasesOnAnyModifier() {
        var b = ShortcutBindings.defaults; b.switcher = KeyCombo(keyCode: tab, modifiers: [.control, .option])
        var c = HotkeyClassifier(bindings: b)
        #expect(c.classify(down(tab, [.control, .option])) == .switcher(.tab(shift: false)))
        #expect(c.classify(.flagsChanged(modifiers: [.control, .option, .shift])) == .pass)
        #expect(c.classify(.flagsChanged(modifiers: [.control])) == .switcher(.controlReleased))
    }
    @Test func commandBacktickSwitcher() {
        var b = ShortcutBindings.defaults; b.switcher = KeyCombo(keyCode: backtick, modifiers: .command)
        var c = HotkeyClassifier(bindings: b)
        #expect(c.classify(down(backtick, [.command])) == .switcher(.tab(shift: false)))
        #expect(c.classify(down(backtick, [.command, .shift])) == .switcher(.tab(shift: true)))
        #expect(c.classify(down(esc, [.command])) == .switcher(.escape))
        #expect(!c.isSwitcherOpen)
        #expect(c.classify(down(backtick, [.command, .option])) == .pass)
    }
    @Test func nilBindingPasses() {
        var defaults = HotkeyClassifier()
        #expect(defaults.classify(down(fKey, [.control, .option, .command])) == .pass)
        var c = HotkeyClassifier(bindings: .disabled)
        let keys: [(UInt16, KeyModifiers)] = [(space, .option), (tab, .option), (tab, .control), (aKey, []), (.max, [])]
        for (key, mods) in keys {
            #expect(c.classify(down(key, mods)) == .pass)
        }
        #expect(!c.isSwitcherOpen)
    }
    @Test func searchFilesAndSettingsActions() {
        var b = ShortcutBindings.defaults
        b.searchFiles = KeyCombo(keyCode: fKey, modifiers: [.control, .option])
        b.settings = KeyCombo(keyCode: comma, modifiers: [.control, .option])
        var c = HotkeyClassifier(bindings: b)
        #expect(c.classify(down(fKey, [.control, .option])) == .openSearchFiles)
        #expect(c.classify(down(fKey, [.control, .option], repeat: true)) == .swallow)
        #expect(c.classify(.keyUp(keyCode: fKey, modifiers: [])) == .swallow)
        #expect(c.classify(down(comma, [.control, .option])) == .openSettings)
        #expect(c.classify(down(fKey, [.control, .option, .shift])) == .pass)
    }
    @Test func bindingsCanChangeAtRuntime() {
        var c = HotkeyClassifier()
        c.bindings.launcher = KeyCombo(keyCode: jKey, modifiers: .command)
        #expect(c.classify(down(jKey, [.command])) == .toggleRootSearch)
        #expect(c.classify(down(space, [.option])) == .pass)
    }
}
