import AppKit
import BeamCore
import SwiftUI

/// `all`: bundles, then windows. `bundle`: one bundle's open windows and files. `picker`: ⌘ G's bundle list.
enum WindowSearchMode: Equatable {
    case all
    case bundle(UUID)
    case picker(PickerTarget)
}

/// A file in the bundle view: one of the bundle's own paths (greyed once it no longer exists) or a saved-search result.
struct BundleFileItem: Hashable {
    let file: FileResult
    let isMissing: Bool
}

enum WindowSearchRow: Identifiable, Equatable {
    case bundle(BundleSummary)
    case window(WindowInfo)
    case file(BundleFileItem)

    var id: String {
        switch self {
        case let .bundle(bundle): Self.bundleRowID(bundle.id)
        case let .window(window): "window-\(window.id)"
        case let .file(item): "file-\(item.file.path)"
        }
    }

    static func bundleRowID(_ id: UUID) -> String { "bundle-\(id.uuidString)" }
}

@MainActor @Observable
final class WindowSearchModel {
    var query = "" {
        didSet {
            if !isRecalling { navigator.reset() } // a user edit ends browsing
            rerank(keepSelection: false)
        }
    }
    var mode = WindowSearchMode.all { didSet { rerank(keepSelection: false) } }
    /// Every window, most recently used first.
    var all: [WindowInfo] = [] { didSet { recount(); rerank(keepSelection: true) } }
    var bundles: [BeamBundle] = [] { didSet { recount(); rerank(keepSelection: true) } }
    /// The open bundle's files: its paths, then its saved searches' results.
    var bundleFiles: [BundleFileItem] = [] { didSet { rerank(keepSelection: true) } }
    private(set) var summaries: [BundleSummary] = []
    /// The list in `all` and `bundle` mode.
    private(set) var results: [WindowSearchRow] = []
    /// The list in `picker` mode.
    private(set) var pickerRows: [BundlePickerRow] = []
    var selection = 0
    /// Where the selection goes when the list is rebuilt for a new query: the first window with an empty field.
    private var initialSelection = 0
    var shakes = 0
    var presentCount = 0
    var navigator = HistoryNavigator()
    private var isRecalling = false
    let fileIcons = FileIcons()
    /// Filled while rows render, so it must not be observed (a write would re-render, forever when an
    /// app has no icon). Misses are cached too.
    @ObservationIgnored private var icons: [pid_t: NSImage?] = [:]

    func icon(for pid: pid_t) -> NSImage? {
        if let cached = icons[pid] { return cached }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
        icons[pid] = .some(icon)
        return icon
    }

    var openBundle: BeamBundle? {
        guard case let .bundle(id) = mode else { return nil }
        return bundles.first { $0.id == id }
    }

    /// The open bundle's windows, most recently used first.
    func members(of bundle: BeamBundle) -> [WindowInfo] {
        BundleMatcher.windows(of: bundle, in: all)
    }

    var rowCount: Int {
        if case .picker = mode { pickerRows.count } else { results.count }
    }

    var selectedRow: WindowSearchRow? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    var windowCount: Int {
        results.count { if case .window = $0 { true } else { false } }
    }

    var fileCount: Int {
        results.count { if case .file = $0 { true } else { false } }
    }

    private var rowIDs: [String] {
        if case .picker = mode { pickerRows.map(\.id) } else { results.map(\.id) }
    }

    var selectedRowID: String? {
        let ids = rowIDs
        return ids.indices.contains(selection) ? ids[selection] : nil
    }

    func select(rowID: String) {
        if let index = rowIDs.firstIndex(of: rowID) { selection = index }
    }

    private func recount() {
        summaries = bundles.map { bundle in
            BundleSummary(id: bundle.id, name: bundle.name, openWindows: members(of: bundle).count, files: bundle.files.count)
        }
    }

    private func rerank(keepSelection: Bool) {
        // A refresh keeps the highlighted window, and any row the user moved to. A default selection that isn't a
        // window (the bundle row before the windows load) moves to the new default: the first window.
        let isWindow = if case .window = selectedRow { true } else { false }
        let selectedID = keepSelection && (isWindow || selection != initialSelection) ? selectedRowID : nil
        switch mode {
        case .all:
            let ranked = BundleSearch.rank(windows: all, bundles: summaries, query: query)
            results = ranked.items.map { item in
                switch item {
                case let .bundle(bundle): .bundle(bundle)
                case let .window(window): .window(window)
                }
            }
            pickerRows = []
            initialSelection = ranked.selection
        case .bundle:
            let members = openBundle.map(members(of:)) ?? []
            let terms = FileQuery.terms(query)
            let files = terms.isEmpty ? bundleFiles : bundleFiles.filter { FileQuery.nameMatches($0.file.name, terms: terms) }
            results = WindowSearchRanker.rank(members, query: query).map(WindowSearchRow.window) + files.map(WindowSearchRow.file)
            pickerRows = []
            initialSelection = 0
        case .picker:
            results = []
            pickerRows = BundleSearch.pickerRows(bundles: summaries, query: query)
            initialSelection = 0
        }
        selection = selectedID.flatMap { id in rowIDs.firstIndex(of: id) } ?? initialSelection
    }

    /// Sets the query from history recall; unlike a user edit, it does not end browsing.
    func recall(_ text: String) {
        isRecalling = true
        query = text
        isRecalling = false
    }

    func resetSelection() { selection = initialSelection }
}

/// Option+Tab: search every window by app name or title, and open bundles.
@MainActor
final class WindowSearchController {
    private let enumerator: WindowEnumerator
    private let activity: WindowActivityMonitor
    private let settings: AppSettings
    private let history: HistoryStore
    private let store: BundleStore
    private let model = WindowSearchModel()
    private let panel = BeamPanel(size: Theme.rootSize, acceptsKeyboard: true)
    /// The main list's query while a bundle is open: restored on the way back, and what history records.
    private var mainQuery = ""
    /// Where the picker returns to (Esc, or after adding).
    private var pickerReturn: (mode: WindowSearchMode, query: String, rowID: String?) = (.all, "", nil)
    /// The open bundle's own paths, and one live query per saved search with its latest results.
    private var bundlePaths: [BundleFileItem] = []
    private var savedSearchers: [FileSearcher] = []
    private var savedResults: [[FileResult]] = []
    private static let savedSearchLimit = 30

    init(enumerator: WindowEnumerator, activity: WindowActivityMonitor, settings: AppSettings, history: HistoryStore,
         bundles: BundleStore) {
        self.enumerator = enumerator
        self.activity = activity
        self.settings = settings
        self.history = history
        self.store = bundles
        panel.host(WindowSearchView(
            model: model,
            onMove: { [weak self] delta in self?.move(delta) },
            onRecall: { [weak self] delta in self?.recallHistory(delta) ?? false },
            onSubmit: { [weak self] in self?.activateSelection() },
            onCancel: { [weak self] in self?.cancel() },
            onActivate: { [weak self] index in self?.activate(index) },
            onKey: { [weak self] key in self?.handle(key) ?? false },
            onBack: { [weak self] in self?.cancel() }
        ))
        panel.onResignKey = { [weak self] in self?.dismiss() }
        DispatchQueue.main.async { [panel] in panel.warmUp() }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        guard !panel.isVisible else { return }
        let signpost = Signpost.begin("windowSearch.open")
        model.navigator.reset()
        endBundleFiles()
        model.mode = .all
        model.query = ""
        model.bundles = store.bundles
        Task {
            let cached = await enumerator.cachedWindows()
            if model.all.isEmpty { model.all = activity.mru.ordered(cached) }
        }
        model.all = activity.mru.ordered(model.all)
        model.resetSelection()
        model.presentCount += 1
        panel.present(on: PanelScreens.screen(for: settings.panelScreen))
        Signpost.end("windowSearch.open", signpost)
        Task {
            let fresh = await enumerator.allWindows()
            model.all = activity.mru.ordered(fresh)
        }
    }

    func dismiss() {
        endBundleFiles() // live saved-search queries keep watching the disk
        panel.dismiss()
    }

    /// Esc (and the bundle header's back arrow): back out of the picker or bundle view, else close.
    private func cancel() {
        switch model.mode {
        case .all: dismiss()
        case .bundle: leaveBundle()
        case .picker: leavePicker()
        }
    }

    private func handle(_ key: PanelKey) -> Bool {
        switch (key, model.mode) {
        case (.commandReturn, .all):
            guard case let .bundle(bundle) = model.selectedRow else { return false } // a window: ⏎ as usual
            bringForward(bundle.id)
            return true
        case let (.commandReturn, .bundle(id)):
            bringForward(id)
            return true
        case (.right, .all):
            guard case let .bundle(bundle) = model.selectedRow else { return false }
            openBundle(bundle.id)
            return true
        case (.addToBundle, .all), (.addToBundle, .bundle):
            guard case let .window(window) = model.selectedRow else { return false }
            openPicker(for: .window(window))
            return true
        case let (.removeFromBundle, .bundle(id)):
            guard model.selectedRow != nil else { return false }
            removeSelection(from: id)
            return true
        case (.left, .bundle), (.left, .picker):
            guard model.query.isEmpty else { return false } // ← moves the caret while there is text
            cancel()
            return true
        case (.backspaceOnEmpty, .bundle), (.backspaceOnEmpty, .picker):
            cancel()
            return true
        default:
            return false
        }
    }

    /// ↑ on an empty field, and ↑/↓ while browsing, step through history instead of the results.
    /// Returns whether the key was used.
    private func recallHistory(_ delta: Int) -> Bool {
        guard model.mode == .all else { return false } // history holds main-list queries
        let browsing = model.navigator.isBrowsing
        guard browsing || (delta < 0 && model.query.isEmpty) else { return false }
        let recalled = delta < 0
            ? model.navigator.older(in: history.windowSearch, fieldIsEmpty: model.query.isEmpty)
            : model.navigator.newer(in: history.windowSearch)
        if let recalled { model.recall(recalled) }
        return browsing || recalled != nil
    }

    /// Moves the selection, which ends history browsing. ↑/↓ reach this only when they didn't recall (never while
    /// browsing), so the reset matters for Tab/⇧Tab: after a recall, a later ↑ moves the selection.
    private func move(_ delta: Int) {
        model.navigator.reset()
        let count = model.rowCount
        guard count > 0 else { return }
        withAnimation(Theme.spring) { model.selection = (model.selection + delta + count) % count }
    }

    private func activateSelection() {
        activate(model.selection)
    }

    private func activate(_ index: Int) {
        if case let .picker(target) = model.mode { return pick(index, for: target) }
        guard model.results.indices.contains(index) else { return }
        model.selection = index
        switch model.results[index] {
        case let .bundle(bundle): openBundle(bundle.id)
        case let .window(window): focus(window)
        case let .file(item): reveal(item)
        }
    }

    private func shake() {
        withAnimation(.linear(duration: 0.3)) { model.shakes += 1 }
    }

    /// The main list's query, recorded in history when a window or file is used.
    private func recordQuery() {
        history.record(model.mode == .all ? model.query : mainQuery, in: .windowSearch)
    }

    private func focus(_ window: WindowInfo) {
        guard window.isReachable else { return shake() }
        Task {
            let screen = panel.screen // so a re-present stays where the panel was
            let element = enumerator.axElement(for: window.id)
            guard element != nil else { return shake() }
            recordQuery()
            panel.dismiss()
            switch await WindowFocuser.focus(window, element: element) {
            case .focused:
                activity.touch(window.id)
            case .unreachable:
                // Nothing changed on screen: bring the panel back and say so.
                panel.present(on: screen)
                shake()
            case .mismatch:
                break
            }
        }
    }

    private func reveal(_ item: BundleFileItem) {
        guard !item.isMissing else { return shake() }
        recordQuery()
        dismiss()
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.file.path)])
    }

    /// ⌘⏎: un-minimize and raise every open member where it is, then focus the most recently used one.
    private func bringForward(_ id: UUID) {
        guard let bundle = store.bundle(id) else { return }
        let members = model.members(of: bundle).filter(\.isReachable)
        guard let latest = members.first else { return shake() }
        recordQuery()
        dismiss()
        Task { [enumerator, activity] in
            let result = await WindowFocuser.bringForward(members, focusing: latest) { enumerator.axElement(for: $0) }
            if result == .focused { activity.touch(latest.id) }
        }
    }

    // MARK: Bundle view

    private func openBundle(_ id: UUID) {
        guard let bundle = store.bundle(id) else { return }
        mainQuery = model.query
        loadFiles(of: bundle)
        model.mode = .bundle(id)
        model.query = ""
    }

    private func leaveBundle() {
        guard case let .bundle(id) = model.mode else { return }
        endBundleFiles()
        model.mode = .all
        model.query = mainQuery
        model.select(rowID: WindowSearchRow.bundleRowID(id))
    }

    /// ⌘⌫: drops the highlighted window's rules, or the highlighted file, from the bundle. A saved search's result
    /// can't be removed on its own.
    private func removeSelection(from id: UUID) {
        guard let row = model.selectedRow, let bundle = store.bundle(id) else { return }
        let index = model.selection
        switch row {
        case let .window(window):
            for rule in bundle.rules where BundleMatcher.matches(rule, window) { store.remove(rule, from: id) }
        case let .file(item):
            guard bundle.files.contains(item.file.path) else { return shake() }
            store.removeFile(item.file.path, from: id)
            bundlePaths.removeAll { $0.file.path == item.file.path }
            publishFiles()
        case .bundle:
            return
        }
        model.bundles = store.bundles
        model.selection = min(index, max(model.rowCount - 1, 0))
    }

    private func loadFiles(of bundle: BeamBundle) {
        endBundleFiles()
        bundlePaths = bundle.files.map { path in
            BundleFileItem(
                file: FileResult(path: path, name: (path as NSString).lastPathComponent, lastUsed: nil, modified: nil),
                isMissing: !FileManager.default.fileExists(atPath: path))
        }
        savedResults = Array(repeating: [], count: bundle.savedSearches.count)
        for (index, saved) in bundle.savedSearches.enumerated() {
            let searcher = FileSearcher()
            savedSearchers.append(searcher)
            searcher.search(terms: FileQuery.terms(saved), scopes: settings.fileScopes, limit: Self.savedSearchLimit) {
                [weak self] results in
                guard let self, savedResults.indices.contains(index) else { return }
                savedResults[index] = results
                publishFiles()
            }
        }
        publishFiles()
    }

    /// The bundle's paths, then saved-search results that aren't among them (each file once).
    private func publishFiles() {
        var seen = Set(bundlePaths.map(\.file.path))
        let found = savedResults.joined()
            .filter { seen.insert($0.path).inserted }
            .map { BundleFileItem(file: $0, isMissing: false) }
        model.bundleFiles = bundlePaths + found
        model.fileIcons.load(model.bundleFiles.map(\.file.path))
    }

    private func endBundleFiles() {
        for searcher in savedSearchers { searcher.cancel() }
        savedSearchers = []
        savedResults = []
        bundlePaths = []
        if !model.bundleFiles.isEmpty { model.bundleFiles = [] }
    }

    // MARK: Picker

    private func openPicker(for target: PickerTarget) {
        pickerReturn = (model.mode, model.query, model.selectedRowID)
        model.mode = .picker(target)
        model.query = ""
    }

    private func leavePicker() {
        model.mode = pickerReturn.mode
        model.query = pickerReturn.query
        if let rowID = pickerReturn.rowID { model.select(rowID: rowID) }
    }

    /// ⏎ in the picker: adds the target to the bundle, creating it first for "New bundle", then goes back.
    private func pick(_ index: Int, for target: PickerTarget) {
        guard model.pickerRows.indices.contains(index) else { return }
        model.selection = index
        let id: UUID
        switch model.pickerRows[index] {
        case let .bundle(bundle):
            id = bundle.id
        case let .newBundle(name):
            guard !name.isEmpty else { return shake() } // type a name first
            id = store.create(named: name).id
        }
        store.add(target, to: id)
        model.bundles = store.bundles
        leavePicker()
    }
}
