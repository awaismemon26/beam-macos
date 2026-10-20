@testable import BeamCore

extension WindowInfo {
    static func fixture(
        id: UInt32 = 1,
        pid: Int32 = 100,
        appName: String = "App",
        appSearchNames: [String]? = nil,
        bundleID: String? = nil,
        title: String = "Window",
        isMinimized: Bool = false,
        spaceNumber: Int? = 1,
        isOnCurrentSpace: Bool = true,
        isReachable: Bool = true
    ) -> WindowInfo {
        WindowInfo(
            id: id, pid: pid, appName: appName, appSearchNames: appSearchNames ?? [appName],
            bundleID: bundleID, title: title, isMinimized: isMinimized, spaceNumber: spaceNumber,
            isOnCurrentSpace: isOnCurrentSpace, isReachable: isReachable
        )
    }
}
