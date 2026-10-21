import AppKit
import BeamCore
import SwiftUI

@MainActor @Observable
final class SwitcherModel {
    var appName = ""
    var appIcon: NSImage?
    var windows: [WindowInfo] = []
    var highlighted = 0
    var shakes = 0
}

/// The Ctrl+Tab panel: all windows of the frontmost app, MRU order. Releasing Control closes without
/// switching; Enter focuses the highlighted window.
@MainActor
final class SwitcherController {
    /// How long to wait for a fresh enumeration before showing cached data.
    private static let freshDeadline: Duration = .milliseconds(8)

    private let enumerator: WindowEnumerator
    private let activity: WindowActivityMonitor
    private let setTapSwitcherOpen: (Bool) -> Void
    private let model = SwitcherModel()
    private let panel = BeamPanel(
        size: CGSize(width: Theme.switcherMaxWidth, height: 480), acceptsKeyboard: false, fitsContent: true)
    private var machine = SwitcherStateMachine()
    private var cache: [pid_t: [WindowInfo]] = [:]
    private var openGeneration = 0
    private var userMoved = false
    private var activationToken: NSObjectProtocol?

    init(enumerator: WindowEnumerator, activity: WindowActivityMonitor, setTapSwitcherOpen: @escaping (Bool) -> Void) {
        self.enumerator = enumerator
        self.activity = activity
        self.setTapSwitcherOpen = setTapSwitcherOpen
        panel.host(SwitcherView(model: model))
        // Keep the cache warm for whichever app becomes frontmost.
        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.prefetch(pid: pid) }
        }
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier { prefetch(pid: pid) }
    }

    func handle(_ key: SwitcherKey) {
        if !machine.isOpen, case .tab = key {
            open(key)
            return
        }
        apply(machine.handle(key, itemCount: model.windows.count))
    }

    private func open(_ key: SwitcherKey) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier
        let signpost = Signpost.begin("switcher.open")
        openGeneration += 1
        let generation = openGeneration
        userMoved = false
        model.appName = app.localizedName ?? ""
        model.appIcon = app.icon
        model.windows = activity.mru.ordered(cache[pid] ?? [])
        apply(machine.handle(key, itemCount: model.windows.count))
        Signpost.end("switcher.open", signpost)

        Task {
            let fresh = await enumerator.windows(ofPID: pid)
            guard generation == openGeneration, machine.isOpen else { cache[pid] = fresh; return }
            cache[pid] = fresh
            let ordered = activity.mru.ordered(fresh)
            guard ordered != model.windows else { return }
            model.windows = ordered
            model.highlighted = userMoved
                ? min(machine.highlighted, max(ordered.count - 1, 0))
                : machine.resetHighlight(itemCount: ordered.count)
            panel.refit()
        }
    }

    private func apply(_ command: SwitcherCommand) {
        switch command {
        case let .open(highlight):
            model.highlighted = highlight
            panel.present()
        case let .move(index):
            userMoved = true
            withAnimation(Theme.spring) { model.highlighted = index }
        case let .focus(index):
            guard model.windows.indices.contains(index) else { return }
            focus(model.windows[index])
        case .close:
            // Esc / Control release were already tracked by the tap; telling it again here could
            // overwrite a newer Ctrl+Tab the tap has seen but this queue hasn't handled yet.
            panel.dismiss()
        case .none:
            break
        }
    }

    private func focus(_ window: WindowInfo) {
        guard window.isReachable else { shake(); return }
        let generation = openGeneration
        Task {
            let element = enumerator.axElement(for: window.id)
            let result = await WindowFocuser.focus(window, element: element)
            if result == .focused { activity.touch(window.id) }
            // The user may have closed and reopened the switcher while focusing ran.
            guard generation == openGeneration else { return }
            switch result {
            case .focused:
                close()
            case .unreachable:
                shake()
            case .mismatch:
                close()
            }
        }
    }

    /// Closes after Beam itself finished (not a key the tap saw), so the tap is told too.
    private func close() {
        guard machine.isOpen else { return }
        apply(machine.handle(.escape, itemCount: model.windows.count))
        setTapSwitcherOpen(false)
    }

    private func shake() {
        withAnimation(.linear(duration: 0.3)) { model.shakes += 1 }
    }

    private func prefetch(pid: pid_t) {
        Task { cache[pid] = await enumerator.windows(ofPID: pid) }
    }
}
