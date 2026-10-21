import AppKit
import ApplicationServices
import BeamCore
import os
import Synchronization

/// An Accessibility element that may cross concurrency domains. AX calls are IPC to the target app
/// and safe from any thread.
struct AXRef: @unchecked Sendable {
    let element: AXUIElement
}

/// Builds `[WindowInfo]` by joining the Accessibility window list of each regular app with
/// CoreGraphics window IDs and SkyLight Space information. Never call from the event-tap thread.
actor WindowEnumerator {
    /// Upper bound for any single AX request so a hung app can never stall Beam.
    static let messagingTimeout: Float = 0.25
    /// Time budget per app for the off-Desktop remote-token search.
    private static let remoteSearchBudget: TimeInterval = 0.030
    private static let remoteSearchLimit: UInt64 = 1000
    private static let minimumSide: CGFloat = 50

    private let ownPID = ProcessInfo.processInfo.processIdentifier
    /// Read outside the actor so focusing a window never waits behind a running enumeration.
    private let elementStore = Mutex<[CGWindowID: AXRef]>([:])
    /// Elements for off-Desktop windows found by the remote-token search, per pid.
    private var remoteElements: [pid_t: [CGWindowID: AXRef]] = [:]
    /// Where the remote-token search resumes for a pid when it ran out of budget.
    private var remoteCursor: [pid_t: UInt64] = [:]
    private var lastAll: [WindowInfo] = []
    private var lastByPID: [pid_t: [WindowInfo]] = [:]

    /// Last enumeration result, for showing a panel instantly while a fresh one runs.
    func cachedWindows() -> [WindowInfo] { lastAll }
    func cachedWindows(ofPID pid: pid_t) -> [WindowInfo] { lastByPID[pid] ?? [] }

    nonisolated func axElement(for id: CGWindowID) -> AXRef? { elementStore.withLock { $0[id] } }

    /// Every window of every regular app, front-to-back.
    func allWindows() -> [WindowInfo] {
        let apps = Self.regularApps(excluding: ownPID)
        let (result, refs) = enumerate(apps: apps)
        elementStore.withLock { $0 = refs } // also drops elements of closed windows
        lastAll = result
        for (pid, windows) in Dictionary(grouping: result, by: \.pid) { lastByPID[pid] = windows }
        return result
    }

    func windows(ofPID pid: pid_t) -> [WindowInfo] {
        guard let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular else { return [] }
        let (result, refs) = enumerate(apps: [AppSnapshot(app)])
        elementStore.withLock { $0.merge(refs) { $1 } }
        lastByPID[pid] = result
        return result
    }

    /// Forget cached remote elements for an app whose windows changed.
    func invalidate(pid: pid_t) {
        remoteElements[pid] = nil
        remoteCursor[pid] = nil
    }

    // MARK: - Enumeration

    struct AppSnapshot: Sendable {
        let pid: pid_t
        let name: String
        let searchNames: [String]
        let bundleID: String?

        init(_ app: NSRunningApplication) {
            pid = app.processIdentifier
            name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "App"
            let fileName = app.bundleURL?.deletingPathExtension().lastPathComponent
            searchNames = [name, fileName].compactMap { $0 }.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
            bundleID = app.bundleIdentifier
        }
    }

    private static func regularApps(excluding ownPID: pid_t) -> [AppSnapshot] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated }
            .map(AppSnapshot.init)
    }

    private struct CGWindow {
        let id: CGWindowID
        let pid: pid_t
        let order: Int
    }

    private func enumerate(apps: [AppSnapshot]) -> ([WindowInfo], [CGWindowID: AXRef]) {
        let pids = Set(apps.map(\.pid))
        let cgWindows = Self.cgWindows(of: pids)
        let cgOrder = Dictionary(cgWindows.map { ($0.id, $0.order) }, uniquingKeysWith: min)
        let spaces = SpaceResolver.snapshot(for: cgWindows.map(\.id))
        let canFocus = PrivateAPIs.canFocusExactWindows

        var result: [(order: Int, info: WindowInfo)] = []
        var refs: [CGWindowID: AXRef] = [:]
        for app in apps {
            let appElement = AXUIElementCreateApplication(app.pid)
            AXUIElementSetMessagingTimeout(appElement, Self.messagingTimeout)

            var found: [CGWindowID: (AXRef, WindowAttributes)] = [:]
            var unidentified: [(AXRef, WindowAttributes)] = []
            for element in Self.windowElements(of: appElement) {
                AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
                guard let attributes = WindowAttributes(element), attributes.isStandard else { continue }
                if let id = PrivateAPIs.windowID(of: element) {
                    found[id] = (AXRef(element: element), attributes)
                } else {
                    unidentified.append((AXRef(element: element), attributes))
                }
            }

            // Windows CoreGraphics knows on other Desktops that AX didn't return: search remote tokens.
            let missing = Set(cgWindows.filter { $0.pid == app.pid && found[$0.id] == nil && !spaces.isOnCurrentSpace($0.id) }.map(\.id))
            if !missing.isEmpty {
                for (id, ref) in remoteSearch(pid: app.pid, missing: missing) where found[id] == nil {
                    if let attributes = WindowAttributes(ref.element), attributes.isStandard {
                        found[id] = (ref, attributes)
                    }
                }
            }

            for (id, (ref, attributes)) in found {
                refs[id] = ref
                let info = WindowInfo(
                    id: id, pid: app.pid, appName: app.name, appSearchNames: app.searchNames, bundleID: app.bundleID,
                    title: attributes.title, isMinimized: attributes.isMinimized,
                    spaceNumber: spaces.spaceNumber(of: id), isOnCurrentSpace: spaces.isOnCurrentSpace(id),
                    isReachable: canFocus
                )
                result.append((cgOrder[id] ?? Int.max, info))
            }
            // Windows whose CGWindowID can't be read can't be focused exactly: list them greyed out.
            for (index, (_, attributes)) in unidentified.enumerated() {
                let syntheticID = UInt32.max - UInt32(truncatingIfNeeded: Int(app.pid) &* 64 &+ index)
                let info = WindowInfo(
                    id: syntheticID, pid: app.pid, appName: app.name, appSearchNames: app.searchNames,
                    bundleID: app.bundleID, title: attributes.title, isMinimized: attributes.isMinimized,
                    spaceNumber: nil, isOnCurrentSpace: true, isReachable: false
                )
                result.append((Int.max, info))
            }
        }
        return (result.sorted { $0.order < $1.order }.map(\.info), refs)
    }

    private static func cgWindows(of pids: Set<pid_t>) -> [CGWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var windows: [CGWindow] = []
        for (order, entry) in list.enumerated() {
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pids.contains(pid),
                  let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= minimumSide, bounds.height >= minimumSide
            else { continue }
            windows.append(CGWindow(id: id, pid: pid, order: order))
        }
        return windows
    }

    private static func windowElements(of app: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    /// Brute-forces AX element tokens for `pid` (the technique AltTab uses) to obtain elements for
    /// windows on other Desktops, which `kAXWindowsAttribute` doesn't return.
    private func remoteSearch(pid: pid_t, missing: Set<CGWindowID>) -> [CGWindowID: AXRef] {
        var known = remoteElements[pid] ?? [:]
        guard let create = PrivateAPIs.axCreateWithRemoteToken else { return known }
        if missing.isSubset(of: Set(known.keys)) { return known }

        let deadline = Date().addingTimeInterval(Self.remoteSearchBudget)
        var elementID = remoteCursor[pid] ?? 0
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid.littleEndian) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f_636f).littleEndian) { Data($0) }) // "coco"

        while elementID < Self.remoteSearchLimit, Date() < deadline {
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID.littleEndian) { Data($0) })
            elementID += 1
            guard let element = create(token as CFData)?.takeRetainedValue() else { continue }
            AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
            guard let id = PrivateAPIs.windowID(of: element), missing.contains(id) else { continue }
            known[id] = AXRef(element: element)
            if missing.isSubset(of: Set(known.keys)) { break }
        }
        remoteCursor[pid] = elementID >= Self.remoteSearchLimit ? 0 : elementID
        remoteElements[pid] = known
        return known
    }
}

/// The few attributes Beam reads from a window element, fetched in one round trip.
struct WindowAttributes {
    let title: String
    let isMinimized: Bool
    let subrole: String?

    var isStandard: Bool {
        subrole == kAXStandardWindowSubrole as String || subrole == kAXDialogSubrole as String
    }

    init?(_ element: AXUIElement) {
        let names = [kAXTitleAttribute, kAXMinimizedAttribute, kAXSubroleAttribute] as CFArray
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, names, AXCopyMultipleAttributeOptions(), &values) == .success,
              let array = values as? [Any], array.count == 3
        else { return nil }
        title = array[0] as? String ?? ""
        isMinimized = (array[1] as? Bool) ?? false
        subrole = array[2] as? String
    }
}
