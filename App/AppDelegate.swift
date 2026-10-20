import AppKit
import BeamCore
import SwiftUI

/// Composition root: owns long-lived services, panels, hotkeys and the menu-bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var onboardingWindow: NSWindow?

    let enumerator = WindowEnumerator()
    let activity = WindowActivityMonitor()
    private var eventTap: EventTap?
    private var switcher: SwitcherController?
    #if DEBUG
    private let focusMenu = NSMenu(title: "Focus window")
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        if !PrivateAPIs.missingSymbols.isEmpty {
            log.error("Missing private symbols: \(PrivateAPIs.missingSymbols.joined(separator: ", "), privacy: .public)")
        }
        if Permissions.isTrusted {
            startServices()
        } else {
            showOnboarding()
        }
    }

    /// Everything that needs Accessibility access.
    private func startServices() {
        log.info("Accessibility granted; starting services")
        activity.onWindowsChanged = { [enumerator] pid in
            Task { await enumerator.invalidate(pid: pid) }
        }
        activity.start()
        Task { _ = await enumerator.allWindows() } // warm the cache

        let tap = EventTap(rootSearch: .defaultRootSearch) { action in
            MainActor.assumeIsolated {
                (NSApp.delegate as? AppDelegate)?.perform(action)
            }
        }
        switcher = SwitcherController(enumerator: enumerator, activity: activity) { [weak tap] open in
            tap?.setSwitcherOpen(open)
        }
        if tap.start() {
            eventTap = tap
        } else {
            log.error("Could not create the keyboard event tap")
        }
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case let .switcher(key):
            switcher?.handle(key)
        case .openWindowSearch, .toggleRootSearch, .pass, .swallow, .reenableTap:
            break
        }
    }

    private func showOnboarding() {
        Permissions.promptOnce()
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.title = "Welcome to Beam"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.startServices()
        })
        window.center()
        onboardingWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Beam")
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Beam", action: #selector(openBeam), keyEquivalent: " ")
        open.keyEquivalentModifierMask = [.option]
        open.target = self
        menu.addItem(open)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        #if DEBUG
        menu.addItem(.separator())
        let dump = NSMenuItem(title: "Dump windows", action: #selector(dumpWindows), keyEquivalent: "")
        dump.target = self
        menu.addItem(dump)
        let focus = NSMenuItem(title: "Focus window", action: nil, keyEquivalent: "")
        focusMenu.delegate = self
        focus.submenu = focusMenu
        menu.addItem(focus)
        #endif

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Beam", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func openBeam() {}

    @objc func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    #if DEBUG
    @objc private func dumpWindows() {
        Task {
            let start = Date()
            let windows = await enumerator.allWindows()
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            log.info("Dump: \(windows.count) windows in \(ms) ms")
            for w in activity.mru.ordered(windows) {
                log.info("  \(w.appName, privacy: .public) | \(w.displayTitle, privacy: .public) | \(w.badge ?? "-", privacy: .public) | reachable=\(w.isReachable)")
            }
        }
    }

    /// Fills the debug "Focus window" submenu from the cached enumeration.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === focusMenu else { return }
        menu.removeAllItems()
        let windows = MainActor.assumeIsolated { cachedForMenu }
        for w in windows {
            let item = NSMenuItem(title: "\(w.appName) — \(w.displayTitle) \(w.badge ?? "")", action: #selector(focusFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = w.id
            item.isEnabled = w.isReachable
            menu.addItem(item)
        }
        Task { cachedForMenu = await enumerator.allWindows() }
    }

    private var cachedForMenu: [WindowInfo] = []

    @objc private func focusFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UInt32,
              let window = cachedForMenu.first(where: { $0.id == id }) else { return }
        Task {
            let element = await enumerator.axElement(for: id)
            let result = await WindowFocuser.focus(window, element: element)
            if result == .focused { activity.touch(id) }
            log.info("Focus \(window.displayTitle, privacy: .public): \(String(describing: result), privacy: .public)")
        }
    }
    #endif
}
