import BeamCore
import Foundation
import Observation

/// Holds the user's bundles and persists them to ~/Library/Application Support/Beam/bundles.json.
@MainActor @Observable
final class BundleStore {
    var bundles: [BeamBundle] {
        didSet { scheduleSave() }
    }

    @ObservationIgnored private let url: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// On disk: `{"version":1,"bundles":[…]}`.
    private struct File: Codable {
        var version = 1
        var bundles: [BeamBundle]
    }

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Beam", isDirectory: true)
        url = directory.appendingPathComponent("bundles.json")
        let saved = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(File.self, from: $0) }
        // Window IDs don't outlive the session, so rules matching one window are dropped on load.
        bundles = (saved?.bundles ?? []).map { bundle in
            var bundle = bundle
            bundle.rules.removeAll { $0.sessionWindowID != nil }
            return bundle
        }
    }

    func bundle(_ id: UUID) -> BeamBundle? {
        bundles.first { $0.id == id }
    }

    @discardableResult
    func create(named name: String) -> BeamBundle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = BeamBundle(name: trimmed.isEmpty ? "New Bundle" : trimmed)
        bundles.append(bundle)
        return bundle
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.name = trimmed }
    }

    func delete(_ id: UUID) {
        bundles.removeAll { $0.id == id }
    }

    func add(_ rule: BundleRule, to id: UUID) {
        update(id) { if !$0.rules.contains(rule) { $0.rules.append(rule) } }
    }

    func addFile(_ path: String, to id: UUID) {
        update(id) { if !$0.files.contains(path) { $0.files.append(path) } }
    }

    func addSavedSearch(_ query: String, to id: UUID) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { if !$0.savedSearches.contains(trimmed) { $0.savedSearches.append(trimmed) } }
    }

    func remove(_ rule: BundleRule, from id: UUID) {
        update(id) { $0.rules.removeAll { $0 == rule } }
    }

    func removeFile(_ path: String, from id: UUID) {
        update(id) { $0.files.removeAll { $0 == path } }
    }

    func removeSavedSearch(_ query: String, from id: UUID) {
        update(id) { $0.savedSearches.removeAll { $0 == query } }
    }

    /// Replaces one bundle's rules (the Settings rule editor edits the whole list).
    func setRules(_ rules: [BundleRule], for id: UUID) {
        update(id) { $0.rules = rules }
    }

    private func update(_ id: UUID, _ change: (inout BeamBundle) -> Void) {
        guard let index = bundles.firstIndex(where: { $0.id == id }) else { return }
        change(&bundles[index])
    }

    private func scheduleSave() {
        saveTask?.cancel()
        // This-session rules stay in memory only.
        let snapshot = File(bundles: bundles.map { bundle in
            var bundle = bundle
            bundle.rules.removeAll { $0.sessionWindowID != nil }
            return bundle
        })
        let url = url
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(snapshot).write(to: url, options: .atomic)
            } catch {
                log.error("Saving bundles failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
