/// An installed application that root search can launch.
public struct AppEntry: Identifiable, Hashable, Sendable {
    /// Absolute bundle path, e.g. "/Applications/Safari.app".
    public let id: String
    public let name: String
    public let bundleID: String?

    public init(id: String, name: String, bundleID: String?) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
    }
}
