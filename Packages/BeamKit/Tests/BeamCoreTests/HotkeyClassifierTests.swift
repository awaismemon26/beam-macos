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
        var c = HotkeyClassifier(rootSearch: KeyCombo(keyCode: 49, modifiers: [.command]))
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
        let data = try JSONEncoder().encode(KeyCombo.defaultRootSearch)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == .defaultRootSearch)
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
}
