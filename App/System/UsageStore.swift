import BeamCore
import Foundation

/// Persists app launch history to ~/Library/Application Support/Beam/usage.json.
@MainActor
final class UsageStore {
    private(set) var stats: UsageStats
    private let url: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Beam", isDirectory: true)
        url = directory.appendingPathComponent("usage.json")
        if let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(UsageStats.self, from: data) {
            stats = decoded
        } else {
            stats = UsageStats()
        }
    }

    func record(_ id: String) {
        stats.record(id, at: Date())
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = stats
        let url = url
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            } catch {
                log.error("Saving usage failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
