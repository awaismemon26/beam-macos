import BeamCore
import CoreGraphics
import Foundation
import Synchronization

/// A session-level keyboard event tap on its own high-priority thread. It swallows exactly Beam's
/// hotkeys (decided by `HotkeyClassifier`) and forwards actions to the main thread. The callback never
/// blocks: no AX, no awaiting.
final class EventTap: @unchecked Sendable {
    private let classifier: Mutex<HotkeyClassifier>
    private let onAction: @Sendable (HotkeyAction) -> Void
    /// Written once in `start()` before the tap thread runs; read only from the tap thread afterwards.
    private var machPort: CFMachPort?

    init(bindings: ShortcutBindings, onAction: @escaping @Sendable (HotkeyAction) -> Void) {
        classifier = Mutex(HotkeyClassifier(bindings: bindings))
        self.onAction = onAction
    }

    /// Returns false when the tap can't be created (Accessibility not granted).
    func start() -> Bool {
        guard machPort == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        machPort = port

        let source = UncheckedBox(CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0))
        let portBox = UncheckedBox(port)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source.value, .commonModes)
            CGEvent.tapEnable(tap: portBox.value, enable: true)
            CFRunLoopRun()
        }
        thread.name = "dev.beam.event-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    /// Keeps the classifier in sync after the UI closed the switcher itself (e.g. after focusing).
    func setSwitcherOpen(_ open: Bool) {
        classifier.withLock { $0.isSwitcherOpen = open }
    }

    func setBindings(_ bindings: ShortcutBindings) {
        classifier.withLock { $0.bindings = bindings }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let raw = Self.rawEvent(type: type, event: event) else { return Unmanaged.passUnretained(event) }
        let action = classifier.withLock { $0.classify(raw) }

        switch action {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .reenableTap:
            if let machPort { CGEvent.tapEnable(tap: machPort, enable: true) }
            // Modifier changes made while disabled were never seen; resync so the switcher can't stay stuck.
            let held = Self.modifiers(CGEventSource.flagsState(.combinedSessionState))
            let resync = classifier.withLock { $0.classify(.flagsChanged(modifiers: held)) }
            if resync != .pass { dispatch(resync) }
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .switcher(.controlReleased):
            dispatch(action)
            return Unmanaged.passUnretained(event) // modifier changes always reach the app
        case .switcher, .openWindowSearch, .toggleRootSearch, .openSearchFiles, .openSettings:
            dispatch(action)
            return nil
        }
    }

    private func dispatch(_ action: HotkeyAction) {
        let onAction = onAction
        DispatchQueue.main.async { onAction(action) }
    }

    private static func rawEvent(type: CGEventType, event: CGEvent) -> RawKeyEvent? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .tapDisabled
        case .keyDown:
            return .keyDown(
                keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                modifiers: modifiers(event.flags),
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
        case .keyUp:
            return .keyUp(keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)), modifiers: modifiers(event.flags))
        case .flagsChanged:
            return .flagsChanged(modifiers: modifiers(event.flags))
        default:
            return nil
        }
    }

    static func modifiers(_ flags: CGEventFlags) -> KeyModifiers {
        var mods: KeyModifiers = []
        if flags.contains(.maskControl) { mods.insert(.control) }
        if flags.contains(.maskAlternate) { mods.insert(.option) }
        if flags.contains(.maskShift) { mods.insert(.shift) }
        if flags.contains(.maskCommand) { mods.insert(.command) }
        return mods
    }
}

struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
