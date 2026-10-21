import AppKit
import BeamCore

/// Keeps one Beam running: a second launch (`open -n`, a stray copy, the login item racing a manual start)
/// either hands over to the better copy or replaces an older one.
@MainActor
enum SingleInstance {
    /// Returns `false` when this process must quit.
    static func resolve() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return true }
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0.processIdentifier != me && !$0.isTerminated }
        let versions = others.map { (pid: $0.processIdentifier, version: version(of: $0.bundleURL)) }
        switch LaunchDecision.decide(own: version(of: Bundle.main.bundleURL), ownPID: me, others: versions) {
        case .proceed:
            return true
        case let .handOff(pid):
            log.info("Beam is already running (pid \(pid)); handing over")
            // Opening the running copy sends it a reopen, which shows Settings.
            if let url = others.first(where: { $0.processIdentifier == pid })?.bundleURL {
                NSWorkspace.shared.open(url)
            }
            return false
        case let .replace(pid):
            log.info("Replacing older Beam (pid \(pid))")
            guard let old = others.first(where: { $0.processIdentifier == pid }) else { return true }
            old.terminate()
            let deadline = Date().addingTimeInterval(2)
            while !old.isTerminated, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            if !old.isTerminated { log.error("Older Beam (pid \(pid)) did not quit in time") }
            return true
        }
    }

    private static func version(of bundleURL: URL?) -> AppVersion {
        let info = bundleURL.flatMap { Bundle(url: $0)?.infoDictionary }
        return AppVersion(
            short: info?["CFBundleShortVersionString"] as? String ?? "0",
            build: info?["CFBundleVersion"] as? String ?? "0"
        )
    }
}
