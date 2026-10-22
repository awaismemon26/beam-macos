import BeamCore
import Foundation

/// Spotlight file-name search (`NSMetadataQuery`) over a set of folders. One live query at a time:
/// a new `search` stops the previous one, and results stream in as Spotlight gathers them.
@MainActor
final class FileSearcher {
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var onResults: (([FileResult]) -> Void)?

    /// Replaces any running search. `onResults` is called on the main actor with the best `limit` matches,
    /// again each time Spotlight reports more. No terms → `[]` and no query.
    func search(terms: [String], scopes: [String], limit: Int, onResults: @escaping ([FileResult]) -> Void) {
        cancel()
        guard !terms.isEmpty, !scopes.isEmpty, limit > 0 else {
            onResults([])
            return
        }
        let (format, arguments) = FileQuery.predicateFormat(terms: terms)
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: format, argumentArray: arguments)
        query.searchScopes = scopes.map { URL(fileURLWithPath: $0, isDirectory: true) }
        query.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false),
            NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false),
        ]
        query.notificationBatchingInterval = 0.1
        self.query = query
        self.onResults = onResults
        let center = NotificationCenter.default
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.deliver(limit: limit) }
            })
        }
        query.start()
    }

    /// Stops the running query and drops its observers; no further results are delivered.
    func cancel() {
        query?.stop()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        query = nil
        onResults = nil
    }

    private func deliver(limit: Int) {
        guard let query, let onResults else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        let count = min(query.resultCount, limit)
        var results: [FileResult] = []
        results.reserveCapacity(count)
        for index in 0..<count {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String
                ?? (path as NSString).lastPathComponent
            results.append(FileResult(
                path: path,
                name: name,
                lastUsed: item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date,
                modified: item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date))
        }
        onResults(FileRanker.sorted(results))
    }
}
