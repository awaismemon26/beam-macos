import AppKit
import BeamCalc
import BeamCore
import SwiftUI

/// Composition root: owns long-lived services, panels, hotkeys and the menu-bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var onboardingWindow: NSWindow?

    let settings = AppSettings()
    let calculator = CalculatorService()
    private var settingsWindow: NSWindow?
    private var settingsCloseToken: NSObjectProtocol?

    let enumerator = WindowEnumerator()
    let activity = WindowActivityMonitor()
    private var eventTap: EventTap?
    private var switcher: SwitcherController?
    private(set) var windowSearch: WindowSearchController?
    private(set) var rootSearch: RootSearchController?
    #if DEBUG
    private let focusMenu = NSMenu(title: "Focus window")
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.applyAppearance()
        installStatusItem()
        settings.onShowInMenuBarChange = { [weak self] visible in self?.statusItem?.isVisible = visible }
        // Launcher + calculator need no permission; window features start once Accessibility is granted.
        LoginItem.applyDefaultOnce()
        rootSearch = RootSearchController(
            calculator: calculator,
            openWindowSearch: { [weak self] in self?.windowSearch?.show() },
            openSettings: { [weak self] in self?.openSettings() }
        )
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
        // Global default for every AX request Beam makes, so a hung app can never stall it for long.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), WindowEnumerator.messagingTimeout)
        activity.onWindowsChanged = { [enumerator] pid in
            Task { await enumerator.invalidate(pid: pid) }
        }
        activity.start()
        Task { _ = await enumerator.allWindows() } // warm the cache

        // Capture self directly: under @NSApplicationDelegateAdaptor, NSApp.delegate is SwiftUI's own object.
        let tap = EventTap(rootSearch: settings.rootHotkey) { [weak self] action in
            MainActor.assumeIsolated {
                self?.perform(action)
            }
        }
        switcher = SwitcherController(enumerator: enumerator, activity: activity) { [weak tap] open in
            tap?.setSwitcherOpen(open)
        }
        windowSearch = WindowSearchController(enumerator: enumerator, activity: activity)
        settings.onRootHotkeyChange = { [weak tap] combo in tap?.setRootSearch(combo) }
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
        case .openWindowSearch:
            windowSearch?.show()
        case .toggleRootSearch:
            rootSearch?.toggle()
        case .pass, .swallow, .reenableTap:
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
        bringToFront(window)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.image
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
        item.isVisible = self.settings.showInMenuBar
        statusItem = item
    }

    /// Opening Beam again (Spotlight, Finder, Dock) shows Settings — the way back when the menu-bar
    /// icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    @objc private func openBeam() {
        rootSearch?.show()
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: SettingsView.size),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = "Beam Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            let calculator = calculator
            let rates = RatesStatus(
                lastUpdate: { await calculator.lastRatesUpdate },
                refresh: { await calculator.refreshRates() }
            )
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings, rates: rates))
            window.center()
            // Drop the content on close so its views disappear: that ends hotkey recording and status polling.
            settingsCloseToken = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.settingsWindow?.contentView = nil
                    self.settingsWindow = nil
                    if let token = self.settingsCloseToken { NotificationCenter.default.removeObserver(token) }
                    self.settingsCloseToken = nil
                }
            }
            settingsWindow = window
        }
        bringToFront(settingsWindow)
    }

    /// Beam has no Dock icon and its panels don't activate it, so macOS may decline `NSApp.activate()`.
    /// Put the window on top regardless, ask politely, and force activation only if that was declined,
    /// so the window also gets keyboard focus.
    private func bringToFront(_ window: NSWindow?) {
        guard let window else { return }
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            MainActor.assumeIsolated {
                guard !NSApp.isActive, window.isVisible else { return }
                log.info("Activation declined; forcing")
                (NSApp as LegacyActivation).activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
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
            let element = enumerator.axElement(for: id)
            let result = await WindowFocuser.focus(window, element: element)
            if result == .focused { activity.touch(id) }
            log.info("Focus \(window.displayTitle, privacy: .public): \(String(describing: result), privacy: .public)")
        }
    }
    #endif
}

/// `NSApplication.activate(ignoringOtherApps:)`, deprecated since macOS 14 but still the only call that
/// brings an accessory (no Dock icon) app's window to the front with keyboard focus.
@MainActor private protocol LegacyActivation {
    func activate(ignoringOtherApps flag: Bool)
}

extension NSApplication: LegacyActivation {}
