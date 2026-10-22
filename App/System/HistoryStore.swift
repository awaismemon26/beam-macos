import BeamCore
import Foundation

/// Persists the launcher and window-search histories to ~/Library/Application Support/Beam/history.json.
@MainActor
final class HistoryStore {
    enum List { case launcher, windowSearch }

    private(set) var launcher: SearchHistory
    private(set) var windowSearch: SearchHistory
    private let url: URL
    private var saveTask: Task<Void, Never>?

    /// On disk: `{"version":1,"launcher":[…],"windowSearch":[…]}`, newest first.
    private struct File: Codable {
        var version = 1
        var launcher: [String]
        var windowSearch: [String]
    }

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Beam", isDirectory: true)
        url = directory.appendingPathComponent("history.json")
        let saved = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(File.self, from: $0) }
        launcher = SearchHistory(entries: saved?.launcher ?? [])
        windowSearch = SearchHistory(entries: saved?.windowSearch ?? [])
    }

    func history(_ list: List) -> SearchHistory {
        switch list {
        case .launcher: launcher
        case .windowSearch: windowSearch
        }
    }

    func record(_ query: String, in list: List) {
        switch list {
        case .launcher: launcher.record(query)
        case .windowSearch: windowSearch.record(query)
        }
        scheduleSave()
    }

    /// A privacy action: written to disk right away, not after the save delay.
    func clearAll() {
        launcher.clear()
        windowSearch.clear()
        saveTask?.cancel()
        saveTask = nil
        Self.write(File(launcher: launcher.entries, windowSearch: windowSearch.entries), to: url)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = File(launcher: launcher.entries, windowSearch: windowSearch.entries)
        let url = url
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            Self.write(snapshot, to: url)
        }
    }

    private static func write(_ file: File, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(file).write(to: url, options: .atomic)
        } catch {
            log.error("Saving history failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
