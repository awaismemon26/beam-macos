import CoreGraphics
import Foundation

/// Which Desktop (Space) each window lives on, and which Desktops are currently visible.
struct SpaceSnapshot: Sendable {
    /// The visible Space on each display.
    let currentSpaceIDs: Set<UInt64>
    /// Space id → 1-based Desktop number, counted per display in Mission Control order.
    let spaceNumber: [UInt64: Int]
    /// Window → the Space it is on (first one, for windows assigned to several).
    let windowSpace: [CGWindowID: UInt64]

    static let empty = SpaceSnapshot(currentSpaceIDs: [], spaceNumber: [:], windowSpace: [:])

    func spaceNumber(of window: CGWindowID) -> Int? {
        windowSpace[window].flatMap { spaceNumber[$0] }
    }

    /// Unknown placement counts as "current" so we never show a misleading Desktop badge.
    func isOnCurrentSpace(_ window: CGWindowID) -> Bool {
        guard let space = windowSpace[window] else { return true }
        return currentSpaceIDs.contains(space)
    }
}

enum SpaceResolver {
    /// Mask for CGSCopySpacesForWindows: include current, other and user spaces.
    private static let allSpacesMask: Int32 = 7

    static func snapshot(for windowIDs: [CGWindowID]) -> SpaceSnapshot {
        guard let mainConnectionID = PrivateAPIs.mainConnectionID,
              let copyManagedDisplaySpaces = PrivateAPIs.copyManagedDisplaySpaces,
              let copySpacesForWindows = PrivateAPIs.copySpacesForWindows
        else { return .empty }

        let connection = mainConnectionID()
        guard let displays = copyManagedDisplaySpaces(connection)?.takeRetainedValue() as? [[String: Any]] else {
            return .empty
        }

        var current: Set<UInt64> = []
        var numbers: [UInt64: Int] = [:]
        for display in displays {
            if let currentSpace = display["Current Space"] as? [String: Any], let id = spaceID(currentSpace) {
                current.insert(id)
            }
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            for (index, space) in spaces.enumerated() {
                if let id = spaceID(space) { numbers[id] = index + 1 }
            }
        }

        var windowSpace: [CGWindowID: UInt64] = [:]
        for windowID in windowIDs {
            let ids = [NSNumber(value: windowID)] as CFArray
            guard let spaces = copySpacesForWindows(connection, allSpacesMask, ids)?.takeRetainedValue() as? [NSNumber],
                  let first = spaces.first
            else { continue }
            // A window on the visible Space of any display counts as current.
            let onCurrent = spaces.first { current.contains($0.uint64Value) }
            windowSpace[windowID] = (onCurrent ?? first).uint64Value
        }
        return SpaceSnapshot(currentSpaceIDs: current, spaceNumber: numbers, windowSpace: windowSpace)
    }

    private static func spaceID(_ dict: [String: Any]) -> UInt64? {
        (dict["id64"] as? NSNumber)?.uint64Value ?? (dict["ManagedSpaceID"] as? NSNumber)?.uint64Value
    }
}
