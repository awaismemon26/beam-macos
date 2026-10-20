/// A single on-screen (or minimized / off-Space) window of a regular app.
public struct WindowInfo: Identifiable, Hashable, Sendable {
    /// The window's `CGWindowID`.
    public let id: UInt32
    public let pid: Int32
    /// The running app's localized name, e.g. "Code" or "Google Chrome".
    public let appName: String
    /// Every name the app can be found by (localized name, bundle file name).
    public let appSearchNames: [String]
    public let bundleID: String?
    public let title: String
    public let isMinimized: Bool
    /// 1-based Mission Control desktop number, `nil` when unknown.
    public let spaceNumber: Int?
    public let isOnCurrentSpace: Bool
    /// Whether Beam can guarantee focusing exactly this window.
    public let isReachable: Bool

    public init(
        id: UInt32, pid: Int32, appName: String, appSearchNames: [String], bundleID: String?,
        title: String, isMinimized: Bool, spaceNumber: Int?, isOnCurrentSpace: Bool, isReachable: Bool
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appSearchNames = appSearchNames
        self.bundleID = bundleID
        self.title = title
        self.isMinimized = isMinimized
        self.spaceNumber = spaceNumber
        self.isOnCurrentSpace = isOnCurrentSpace
        self.isReachable = isReachable
    }

    public var displayTitle: String {
        title.isEmpty ? "\(appName) — untitled" : title
    }

    /// Dim right-aligned label: "Minimized" wins over "Desktop N"; windows on the current desktop have none.
    public var badge: String? {
        if isMinimized { return "Minimized" }
        if !isOnCurrentSpace, let spaceNumber { return "Desktop \(spaceNumber)" }
        return nil
    }
}
