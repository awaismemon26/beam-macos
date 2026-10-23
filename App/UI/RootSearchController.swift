import AppKit
import BeamCalc
import BeamCore
import SwiftUI

enum RootCommand: String, CaseIterable {
    case switchWindows = "Switch Windows"
    case searchFiles = "Search Files"
    case settings = "Beam Settings"

    var systemImage: String {
        switch self {
        case .switchWindows: "macwindow.on.rectangle"
        case .searchFiles: "doc.text.magnifyingglass"
        case .settings: "gearshape"
        }
    }

    /// Title plus the words people type for it.
    var names: [String] {
        switch self {
        case .switchWindows: [rawValue, "Windows", "Window Search"]
        case .searchFiles: [rawValue, "Files", "Find File"]
        case .settings: [rawValue, "Settings", "Preferences"]
        }
    }
}

enum RootItem: Identifiable, Equatable {
    case calculation(CalculationResult)
    case app(AppEntry)
    case command(RootCommand)
    case file(FileResult)

    var id: String {
        switch self {
        case .calculation: "calc"
        case let .app(app): "app:" + app.id
        case let .command(command): "cmd:" + command.rawValue
        case let .file(file): "file:" + file.path
        }
    }
}

/// `root`: apps, commands, calculations (and inline files for `f …`). `files`: the Search Files view.
/// `picker`: ⌘ G / ⇧⌘ G's bundle list, shown in place of the results.
enum RootMode: Equatable {
    case root, files
    case picker(PickerTarget)
}

@MainActor @Observable
final class RootSearchModel {
    var query = ""
    var mode = RootMode.root
    var items: [RootItem] = []
    var selection = 0
    var presentCount = 0
    var showsCopied = false
    var icons: [String: NSImage] = [:]
    let fileIcons = FileIcons()
    /// The list in `picker` mode.
    var pickerRows: [BundlePickerRow] = []
    /// Bumped to shake the panel (a bundle can't be created without a name).
    var shakes = 0

    var isPicker: Bool {
        if case .picker = mode { true } else { false }
    }
}

/// Option+Space: launch apps, run calculations, jump to window search.
@MainActor
final class RootSearchController {
    private let calculator: CalculatorService
    private let settings: AppSettings
    private let history: HistoryStore
    private let store: BundleStore
    private let enumerator: WindowEnumerator
    private let appIndex = AppIndex()
    private let usage = UsageStore()
    private let model = RootSearchModel()
    private let panel = BeamPanel(size: Theme.rootSize, acceptsKeyboard: true)
    private let openWindowSearch: () -> Void
    private let openSettings: () -> Void
    private let fileSearcher = FileSearcher()
    private var apps: [AppEntry] = []
    /// The words being searched for in file names, while the query is a file search; nil otherwise.
    private var fileTerms: [String]?
    private var fileResults: [FileResult] = []
    private var calcTask: Task<Void, Never>?
    private var calcResult: CalculationResult?
    private var navigator = HistoryNavigator()
    /// Where the picker returns to (Esc, or after adding): the list it was opened from.
    private var pickerReturn: (mode: RootMode, query: String, rowID: String?) = (.root, "", nil)
    /// The row to highlight once the restored query has rebuilt the list.
    private var pendingRowID: String?
    /// Bundles with their open-window counts, for the picker's rows.
    private var summaries: [BundleSummary] = []
    /// The query set by ↑/↓ recall, so the change it causes is not mistaken for typing.
    private var recalledQuery: String?
    private static let rateRefreshInterval: Duration = .seconds(6 * 3600)
    /// Files shown inline for `f …` in the launcher, and in the Search Files view.
    private static let inlineFileLimit = 8
    private static let fileViewLimit = 50

    init(calculator: CalculatorService, settings: AppSettings, history: HistoryStore, bundles: BundleStore, enumerator: WindowEnumerator,
         openWindowSearch: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.calculator = calculator
        self.settings = settings
        self.history = history
        self.store = bundles
        self.enumerator = enumerator
        self.openWindowSearch = openWindowSearch
        self.openSettings = openSettings
        panel.host(RootSearchView(
            model: model,
            onQueryChange: { [weak self] in self?.queryChanged() },
            onMove: { [weak self] delta in self?.move(delta) },
            onRecall: { [weak self] delta in self?.recallHistory(delta) ?? false },
            onSubmit: { [weak self] in self?.activate(self?.model.selection ?? 0) },
            onCancel: { [weak self] in self?.cancel() },
            onActivate: { [weak self] index in self?.activate(index) },
            onSettings: { [weak self] in self?.dismiss(); openSettings() },
            onKey: { [weak self] key in self?.handle(key) ?? false }
        ))
        panel.onResignKey = { [weak self] in self?.dismiss() }
        DispatchQueue.main.async { [panel] in panel.warmUp() }

        Task { [weak self, appIndex] in
            await appIndex.start { [weak self] in
                Task { @MainActor in await self?.reloadApps() }
            }
            await self?.reloadApps()
        }
        Task { [calculator] in
            while !Task.isCancelled {
                await calculator.refreshRates()
                try? await Task.sleep(for: Self.rateRefreshInterval)
            }
        }
    }

    func toggle() {
        panel.isVisible ? dismiss() : show()
    }

    func show() {
        let signpost = Signpost.begin("root.open")
        navigator.reset()
        recalledQuery = nil
        model.query = ""
        model.mode = .root
        model.showsCopied = false
        calcResult = nil
        endFileSearch()
        rebuildItems()
        model.selection = 0
        model.presentCount += 1
        panel.present(on: PanelScreens.screen(for: settings.panelScreen))
        Signpost.end("root.open", signpost)
    }

    /// Opens the launcher straight into the Search Files view (the Search Files shortcut). Does nothing
    /// while File Search is off.
    func showFileSearch() {
        guard settings.fileSearchEnabled else { return }
        show()
        setMode(.files)
    }

    /// Writes pending usage counts (Beam is quitting).
    func flush() {
        usage.flush()
    }

    func dismiss() {
        calcTask?.cancel()
        fileSearcher.cancel() // a live query keeps watching the disk
        panel.dismiss()
    }

    /// Esc: back from the Search Files view to the launcher, else close.
    private func cancel() {
        switch model.mode {
        case .files: setMode(.root)
        case .picker: leavePicker()
        case .root: dismiss()
        }
    }

    private func setMode(_ mode: RootMode) {
        model.mode = mode
        navigator.reset()
        recalledQuery = nil
        if model.query.isEmpty { queryChanged() } else { model.query = "" } // the change runs queryChanged
    }

    private func handle(_ key: PanelKey) -> Bool {
        switch key {
        case .commandReturn:
            guard !model.isPicker, model.items.indices.contains(model.selection),
                  case let .file(file) = model.items[model.selection] else { return false }
            recordQuery()
            dismiss()
            NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
            return true
        case .backspaceOnEmpty:
            switch model.mode {
            case .files: setMode(.root)
            case .picker: leavePicker()
            case .root: return false
            }
            return true
        case .addToBundle:
            guard !model.isPicker, model.items.indices.contains(model.selection),
                  case let .file(file) = model.items[model.selection] else { return false }
            openPicker(for: .file(file.path))
            return true
        case .saveSearchToBundle:
            // The file-search words, without the `f ` prefix.
            guard !model.isPicker, let terms = fileTerms, !terms.isEmpty else { return false }
            openPicker(for: .savedSearch(terms.joined(separator: " ")))
            return true
        case .left:
            guard model.isPicker, model.query.isEmpty else { return false } // ← moves the caret while there is text
            leavePicker()
            return true
        case .removeFromBundle, .right:
            return false
        }
    }

    // MARK: Picker

    private func openPicker(for target: PickerTarget) {
        guard !model.isPicker else { return }
        pickerReturn = (model.mode, model.query, model.items.indices.contains(model.selection) ? model.items[model.selection].id : nil)
        fileSearcher.cancel() // a live query keeps watching the disk; leaving the picker restarts it
        navigator.reset()
        Task {
            // Open-window counts come from the last enumeration; the row text is wrong without them.
            let windows = await enumerator.cachedWindows()
            guard panel.isVisible, !model.isPicker else { return }
            summaries = store.bundles.map { bundle in
                BundleSummary(id: bundle.id, name: bundle.name,
                              openWindows: BundleMatcher.windows(of: bundle, in: windows).count, files: bundle.files.count)
            }
            model.mode = .picker(target)
            model.query = ""
            rebuildPicker()
        }
    }

    private func rebuildPicker() {
        let picker = BundleSearch.pickerRows(bundles: summaries, query: model.query)
        model.pickerRows = picker.rows
        model.selection = picker.selection
    }

    private func leavePicker() {
        guard model.isPicker else { return }
        model.mode = pickerReturn.mode
        pendingRowID = pickerReturn.rowID
        model.query = pickerReturn.query // the change rebuilds the list and runs the file search again
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
            guard !name.isEmpty else { return withAnimation(.linear(duration: 0.3)) { model.shakes += 1 } } // type a name first
            id = store.create(named: name).id
        }
        store.add(target, to: id)
        leavePicker()
    }

    private func reloadApps() async {
        apps = await appIndex.apps()
        if panel.isVisible { rebuildItems() }
    }

    private func queryChanged() {
        let signpost = Signpost.begin("root.query")
        if model.isPicker {
            navigator.reset()
            rebuildPicker()
            return
        }
        let query = model.query
        if query == recalledQuery {
            recalledQuery = nil
        } else {
            navigator.reset() // a user edit ends browsing
        }
        calcResult = nil
        updateFileSearch()
        rebuildItems()
        model.selection = pendingRowID.flatMap { id in model.items.firstIndex { $0.id == id } } ?? 0
        pendingRowID = nil
        Signpost.end("root.query", signpost)

        calcTask?.cancel()
        guard model.mode == .root, fileTerms == nil,
              settings.showCalculator, CalculatorGate.looksLikeCalculation(query) else { return }
        calcTask = Task { [calculator] in
            let result = await calculator.evaluate(query)
            guard !Task.isCancelled, model.query == query else { return }
            calcResult = result
            rebuildItems()
            if result != nil { model.selection = 0 }
        }
    }

    /// Starts (or ends) the Spotlight query for the current text. Until it answers, the previous results stay,
    /// narrowed to the names that still match, so typing doesn't flash an empty list.
    private func updateFileSearch() {
        let text: String? = switch model.mode {
        case .files: model.query
        case .picker: nil
        case .root: settings.fileSearchEnabled ? FileQuery.prefixedTerms(model.query) : nil
        }
        guard let text else { return endFileSearch() }
        let terms = FileQuery.terms(text)
        fileTerms = terms
        fileResults = terms.isEmpty ? [] : fileResults.filter { FileQuery.nameMatches($0.name, terms: terms) }
        let query = model.query
        let limit = model.mode == .files ? Self.fileViewLimit : Self.inlineFileLimit
        fileSearcher.search(terms: terms, scopes: settings.fileScopes, limit: limit) { [weak self] results in
            guard let self, model.query == query else { return }
            // Keep the highlighted file as results stream in, unless it is still the first row.
            let selectedID = model.selection > 0 && model.items.indices.contains(model.selection)
                ? model.items[model.selection].id : nil
            fileResults = results
            rebuildItems()
            model.selection = selectedID.flatMap { id in model.items.firstIndex { $0.id == id } } ?? 0
        }
    }

    private func endFileSearch() {
        fileSearcher.cancel()
        fileTerms = nil
        fileResults = []
    }

    /// Calculator card (if any) on top, then apps, with matching commands around them: a command that
    /// matches better than every app ("settings" → Beam Settings) goes above the apps, the rest below.
    /// The calc row never removes app rows. A file search shows only files.
    private func rebuildItems() {
        if fileTerms != nil {
            let limit = model.mode == .files ? Self.fileViewLimit : Self.inlineFileLimit
            return finish(fileResults.prefix(limit).map(RootItem.file))
        }
        let query = model.query
        var items: [RootItem] = []
        if let calcResult { items.append(.calculation(calcResult)) }
        let rankedApps = AppRanker.rank(apps, query: query, usage: usage.stats, now: Date())
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            items += rankedApps.map(RootItem.app)
            return finish(items)
        }
        let bestApp = rankedApps.compactMap { FuzzyMatcher.match(query, in: $0.name) }.max()
        let commands = RootCommand.allCases
            .filter { $0 != .searchFiles || settings.fileSearchEnabled }
            .compactMap { command in CommandRanker.match(query, names: command.names).map { (command, $0) } }
            .sorted { $0.1 > $1.1 }
        let promoted = commands.filter { CommandRanker.outranksApps($0.1, bestApp: bestApp) }
        items += promoted.map { RootItem.command($0.0) }
        items += rankedApps.map(RootItem.app)
        items += commands.filter { !CommandRanker.outranksApps($0.1, bestApp: bestApp) }.map { RootItem.command($0.0) }
        finish(items)
    }

    private func finish(_ items: [RootItem]) {
        model.items = items
        if model.selection >= items.count { model.selection = max(items.count - 1, 0) }
        loadIcons(for: items)
        model.fileIcons.load(items.compactMap { if case let .file(file) = $0 { file.path } else { nil } })
    }

    private func loadIcons(for items: [RootItem]) {
        for case let .app(app) in items where model.icons[app.id] == nil {
            let path = app.id
            Task.detached(priority: .userInitiated) {
                let icon = NSWorkspace.shared.icon(forFile: path)
                await MainActor.run { [weak self] in self?.model.icons[path] = icon }
            }
        }
    }

    /// ↑ on an empty field, and ↑/↓ while browsing, step through history instead of the results.
    /// Returns whether the key was used.
    private func recallHistory(_ delta: Int) -> Bool {
        guard model.mode == .root else { return false } // history holds launcher queries (`f …` included)
        let browsing = navigator.isBrowsing
        guard browsing || (delta < 0 && model.query.isEmpty) else { return false }
        let recalled = delta < 0
            ? navigator.older(in: history.launcher, fieldIsEmpty: model.query.isEmpty)
            : navigator.newer(in: history.launcher)
        if let recalled, recalled != model.query {
            recalledQuery = recalled
            model.query = recalled
        }
        return browsing || recalled != nil
    }

    /// Moves the selection, which ends history browsing. ↑/↓ reach this only when they didn't recall (never while
    /// browsing), so the reset matters for Tab/⇧Tab: after a recall, a later ↑ moves the selection.
    private func move(_ delta: Int) {
        navigator.reset()
        let count = model.isPicker ? model.pickerRows.count : model.items.count
        guard count > 0 else { return }
        withAnimation(Theme.spring) { model.selection = (model.selection + delta + count) % count }
    }

    /// Records the launcher query in history; in the Search Files view as `f …`, which recalls the same search.
    private func recordQuery() {
        let query = model.mode == .files ? "f " + model.query.trimmingCharacters(in: .whitespaces) : model.query
        history.record(query, in: .launcher)
    }

    private func activate(_ index: Int) {
        if case let .picker(target) = model.mode { return pick(index, for: target) }
        guard model.items.indices.contains(index) else { return }
        recordQuery()
        switch model.items[index] {
        case let .calculation(result):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.value, forType: .string)
            withAnimation(Theme.spring) { model.showsCopied = true }
            let presentation = model.presentCount
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard presentation == model.presentCount else { return } // reopened meanwhile
                dismiss()
            }
        case let .app(app):
            usage.record(app.id)
            dismiss()
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: app.id), configuration: .init()) { _, error in
                if let error { log.error("Launch failed: \(error.localizedDescription, privacy: .public)") }
            }
        case let .file(file):
            dismiss()
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
        case .command(.switchWindows):
            dismiss()
            openWindowSearch()
        case .command(.searchFiles):
            setMode(.files)
        case .command(.settings):
            // Open first, while Beam still holds the key panel: macOS only lets an app that the user is
            // interacting with take the front.
            openSettings()
            dismiss()
        }
    }
}
