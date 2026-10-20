import AppKit
import BeamCore
import SwiftUI

/// Composition root: owns long-lived services, panels, hotkeys and the menu-bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var onboardingWindow: NSWindow?

    let enumerator = WindowEnumerator()

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
            for w in windows {
                log.info("  \(w.appName, privacy: .public) | \(w.displayTitle, privacy: .public) | \(w.badge ?? "-", privacy: .public) | reachable=\(w.isReachable)")
            }
        }
    }
    #endif
}
