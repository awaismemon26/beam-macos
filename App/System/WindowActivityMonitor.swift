import AppKit
import ApplicationServices
import BeamCore

/// Keeps a most-recently-used window list up to date by observing focus changes in every regular app
/// (AXObserver) and app activations (NSWorkspace). No polling.
@MainActor
final class WindowActivityMonitor {
    private(set) var mru = MRUList()
    /// Fires with the pid of an app that created a window, so cached enumerations can refresh.
    var onWindowsChanged: ((pid_t) -> Void)?

    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []

    private static let appNotifications = [
        kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXWindowCreatedNotification,
    ]

    func start() {
        let workspace = NSWorkspace.shared
        for app in workspace.runningApplications where app.activationPolicy == .regular {
            observe(pid: app.processIdentifier)
        }
        if let frontmost = workspace.frontmostApplication {
            touchFocusedWindow(of: frontmost.processIdentifier)
        }

        let center = workspace.notificationCenter
        workspaceTokens.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.observe(pid: pid) }
        })
        workspaceTokens.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.stopObserving(pid: pid) }
        })
        workspaceTokens.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.touchFocusedWindow(of: pid) }
        })
    }

    /// Record a window as just used (also called after Beam focuses one).
    func touch(_ id: CGWindowID) {
        mru.touch(id)
    }

    private func touchFocusedWindow(of pid: pid_t) {
        if let id = WindowFocuser.focusedWindowID(ofPID: pid) { mru.touch(id) }
    }

    private func observe(pid: pid_t) {
        guard observers[pid] == nil, pid != ProcessInfo.processInfo.processIdentifier else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, Self.callback, &observer) == .success, let observer else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, WindowEnumerator.messagingTimeout)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.appNotifications {
            AXObserverAddNotification(observer, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func stopObserving(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func handle(notification: String, element: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        switch notification {
        case kAXWindowCreatedNotification:
            onWindowsChanged?(pid)
        default:
            // For focus/main-window changes the element is the window itself.
            if let id = PrivateAPIs.windowID(of: element) {
                mru.touch(id)
            } else {
                touchFocusedWindow(of: pid)
            }
        }
    }

    /// Runs on the main run loop (the observers' sources are added there).
    private static let callback: AXObserverCallback = { _, element, notification, refcon in
        guard let refcon else { return }
        let monitor = Unmanaged<WindowActivityMonitor>.fromOpaque(refcon).takeUnretainedValue()
        let name = notification as String
        let ref = AXRef(element: element)
        MainActor.assumeIsolated {
            monitor.handle(notification: name, element: ref.element)
        }
    }
}
