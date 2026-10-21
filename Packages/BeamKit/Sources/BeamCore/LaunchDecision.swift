/// An app version as shown to people (`CFBundleShortVersionString`) plus its build number.
public struct AppVersion: Comparable, Sendable {
    private let short: [Int], build: [Int]

    public init(short: String, build: String) {
        self.short = Self.numbers(short)
        self.build = Self.numbers(build)
    }

    /// Dotted numeric parts; anything that is not a number counts as 0.
    private static func numbers(_ s: String) -> [Int] {
        s.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    }

    /// -1, 0 or 1; missing trailing parts count as 0 ("1.1" == "1.1.0").
    private static func compare(_ a: [Int], _ b: [Int]) -> Int {
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
    /// `short` decides first, `build` breaks a tie.
    private static func order(_ l: AppVersion, _ r: AppVersion) -> Int {
        let s = compare(l.short, r.short)
        return s != 0 ? s : compare(l.build, r.build)
    }

    public static func == (l: AppVersion, r: AppVersion) -> Bool { order(l, r) == 0 }
    public static func < (l: AppVersion, r: AppVersion) -> Bool { order(l, r) < 0 }
}

/// What a freshly launched Beam does when other copies are already running.
public enum LaunchDecision: Equatable, Sendable {
    case proceed
    /// A better copy is running: ask it to show Settings, then quit.
    case handOff(to: Int32)
    /// This copy is newer: quit the other one and take over.
    case replace(Int32)

    /// The newest version wins; for equal versions the lowest PID wins, so two simultaneous launches agree.
    public static func decide(own: AppVersion, ownPID: Int32, others: [(pid: Int32, version: AppVersion)]) -> LaunchDecision {
        let best = others.max { a, b in
            a.version != b.version ? a.version < b.version : a.pid > b.pid
        }
        guard let best else { return .proceed }
        if own != best.version { return own > best.version ? .replace(best.pid) : .handOff(to: best.pid) }
        return ownPID < best.pid ? .proceed : .handOff(to: best.pid)
    }
}

/// Decides when the launch-at-login item may be re-pointed at the running copy.
public enum LoginItemPolicy {
    /// Only the installed copy in /Applications takes the login item over; a stray copy (Downloads, a
    /// mounted disk image) leaves a working registration alone and only repairs a missing one.
    public static func shouldRepointLoginItem(bundlePath: String, currentTargetExists: Bool) -> Bool {
        bundlePath.hasPrefix("/Applications/") || !currentTargetExists
    }
}
