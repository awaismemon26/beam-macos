import AppKit
import BeamCore

/// Installed applications, scanned at launch and rescanned when an application folder changes.
actor AppIndex {
    private static let folders: [String] = [
        "/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
    ]
    private static let extraApps = ["/System/Library/CoreServices/Finder.app"]

    private var entries: [AppEntry] = []
    private var sources: [any DispatchSourceFileSystemObject] = []
    private var rescanTask: Task<Void, Never>?
    private var onChange: (@Sendable () -> Void)?

    func start(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        entries = Self.scan()
        watchFolders()
    }

    func apps() -> [AppEntry] { entries }

    private func watchFolders() {
        for folder in Self.folders {
            let fd = open(folder, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .global(qos: .utility))
            source.setEventHandler { [weak self] in
                Task { await self?.scheduleRescan() }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    /// Coalesces bursts of file-system events (an install touches the folder many times).
    private func scheduleRescan() {
        rescanTask?.cancel()
        rescanTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            entries = Self.scan()
            onChange?()
        }
    }

    private static func scan() -> [AppEntry] {
        let fm = FileManager.default
        var seen: Set<String> = []
        var result: [AppEntry] = []

        func add(_ path: String) {
            let resolved = (path as NSString).resolvingSymlinksInPath
            guard seen.insert(resolved).inserted else { return }
            let name = (fm.displayName(atPath: path) as NSString).deletingPathExtension
            result.append(AppEntry(id: path, name: name, bundleID: Bundle(path: path)?.bundleIdentifier))
        }

        for folder in folders {
            guard let items = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            for item in items where !item.hasPrefix(".") {
                let path = (folder as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    add(path)
                } else if folders.contains(path) {
                    continue // scanned on its own
                } else if let sub = try? fm.contentsOfDirectory(atPath: path) {
                    for child in sub where child.hasSuffix(".app") {
                        add((path as NSString).appendingPathComponent(child))
                    }
                }
            }
        }
        for path in extraApps where fm.fileExists(atPath: path) { add(path) }
        return result
    }
}
