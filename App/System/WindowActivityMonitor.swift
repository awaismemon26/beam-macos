import AppKit
import ApplicationServices
import BeamCore

/// Keeps a most-recently-used window list up to date by observing focus changes in every regular app
/// (AXObserver) and app activations (NSWorkspace). No polling. AX requests run on a serial queue
/// (in order, so MRU updates keep their sequence) and never on the main thread.
@MainActor
final class WindowActivityMonitor {
    private(set) var mru = MRUList()
    /// Fires with the pid of an app that created a window, so cached enumerations can refresh.
    var onWindowsChanged: ((pid_t) -> Void)?

    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private let axQueue = DispatchQueue(label: "dev.beam.window-activity", qos: .userInitiated)

    /// A freshly launched app often rejects AX registration until it has finished starting.
    private nonisolated static let registrationRetryDelays: [Double] = [0.5, 1, 2, 4, 8]

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
        touchOffMain { WindowFocuser.focusedWindowID(ofPID: pid) }
    }

    /// Runs `lookup` on the AX queue and records its window as used, back on the main thread.
    private func touchOffMain(_ lookup: @escaping @Sendable () -> CGWindowID?) {
        axQueue.async { [weak self] in
            guard let id = lookup() else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.mru.touch(id) }
            }
        }
    }

    private func observe(pid: pid_t) {
        guard observers[pid] == nil, pid != ProcessInfo.processInfo.processIdentifier else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, Self.callback, &observer) == .success, let observer else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        register(
            UncheckedBox(observer), pid: pid, names: Self.appNotifications,
            refcon: UncheckedBox(Unmanaged.passUnretained(self).toOpaque()), attempt: 0, delay: 0
        )
    }

    /// Adds the notifications on the AX queue, retrying the ones the app rejected.
    private nonisolated func register(
        _ observer: UncheckedBox<AXObserver>, pid: pid_t, names: [String],
        refcon: UncheckedBox<UnsafeMutableRawPointer>, attempt: Int, delay: Double
    ) {
        axQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, NSRunningApplication(processIdentifier: pid) != nil else { return }
            let app = AXUIElementCreateApplication(pid)
            let failed = names.filter { name in
                let error = AXObserverAddNotification(observer.value, app, name as CFString, refcon.value)
                return error != .success && error != .notificationAlreadyRegistered
            }
            guard !failed.isEmpty else { return }
            guard attempt < Self.registrationRetryDelays.count else {
                log.error("AX observer registration failed for pid \(pid)")
                return
            }
            register(observer, pid: pid, names: failed, refcon: refcon, attempt: attempt + 1,
                     delay: Self.registrationRetryDelays[attempt])
        }
    }

    private func stopObserving(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func handle(notification: String, element: AXUIElement) {
        var owner: pid_t = 0
        AXUIElementGetPid(element, &owner)
        let pid = owner
        switch notification {
        case kAXWindowCreatedNotification:
            onWindowsChanged?(pid)
        default:
            // For focus/main-window changes the element is the window itself.
            let ref = AXRef(element: element)
            touchOffMain { PrivateAPIs.windowID(of: ref.element) ?? WindowFocuser.focusedWindowID(ofPID: pid) }
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
