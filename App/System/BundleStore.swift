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
    /// False when an unreadable bundles.json couldn't be moved aside: saving would overwrite it, so this session
    /// keeps its changes in memory only.
    @ObservationIgnored private let canSave: Bool

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Beam", isDirectory: true)
        url = directory.appendingPathComponent("bundles.json")
        (bundles, canSave) = Self.load(from: url)
    }

    /// Reads the saved bundles. A file that exists but can't be used (corrupt, hand-broken, or written by a newer
    /// Beam) is moved aside rather than left to be overwritten by the next save, so no bundles are lost. When it
    /// can't be moved either, saving is off for the session.
    private static func load(from url: URL) -> (bundles: [BeamBundle], canSave: Bool) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ([], true) }
        if let data = try? Data(contentsOf: url), let file = BundleFile.decode(data) {
            return (file.withoutSessionRules().bundles, true)
        }
        let aside = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            log.error("bundles.json couldn't be read; kept it as \(aside.lastPathComponent, privacy: .public)")
            return ([], true)
        } catch {
            log.error("bundles.json couldn't be read or moved aside; bundles won't be saved this session: \(error.localizedDescription, privacy: .public)")
            return ([], false)
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
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes pending changes now (also called when Beam quits, so the last second of edits isn't lost).
    func flush() {
        guard let saveTask else { return }
        saveTask.cancel()
        self.saveTask = nil
        guard canSave else { return }
        // This-session rules stay in memory only.
        let snapshot = BundleFile(bundles: bundles).withoutSessionRules()
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
