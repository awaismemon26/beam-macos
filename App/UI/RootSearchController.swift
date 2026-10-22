import AppKit
import BeamCalc
import BeamCore
import SwiftUI

enum RootCommand: String, CaseIterable {
    case switchWindows = "Switch Windows"
    case settings = "Beam Settings"

    var systemImage: String {
        switch self {
        case .switchWindows: "macwindow.on.rectangle"
        case .settings: "gearshape"
        }
    }

    /// Title plus the words people type for it.
    var names: [String] {
        switch self {
        case .switchWindows: [rawValue, "Windows", "Window Search"]
        case .settings: [rawValue, "Settings", "Preferences"]
        }
    }
}

enum RootItem: Identifiable, Equatable {
    case calculation(CalculationResult)
    case app(AppEntry)
    case command(RootCommand)

    var id: String {
        switch self {
        case .calculation: "calc"
        case let .app(app): "app:" + app.id
        case let .command(command): "cmd:" + command.rawValue
        }
    }
}

@MainActor @Observable
final class RootSearchModel {
    var query = ""
    var items: [RootItem] = []
    var selection = 0
    var presentCount = 0
    var showsCopied = false
    var icons: [String: NSImage] = [:]
}

/// Option+Space: launch apps, run calculations, jump to window search.
@MainActor
final class RootSearchController {
    private let calculator: CalculatorService
    private let settings: AppSettings
    private let history: HistoryStore
    private let appIndex = AppIndex()
    private let usage = UsageStore()
    private let model = RootSearchModel()
    private let panel = BeamPanel(size: Theme.rootSize, acceptsKeyboard: true)
    private let openWindowSearch: () -> Void
    private let openSettings: () -> Void
    private var apps: [AppEntry] = []
    private var calcTask: Task<Void, Never>?
    private var calcResult: CalculationResult?
    private var navigator = HistoryNavigator()
    /// The query set by ↑/↓ recall, so the change it causes is not mistaken for typing.
    private var recalledQuery: String?
    private static let rateRefreshInterval: Duration = .seconds(6 * 3600)

    init(calculator: CalculatorService, settings: AppSettings, history: HistoryStore, openWindowSearch: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.calculator = calculator
        self.settings = settings
        self.history = history
        self.openWindowSearch = openWindowSearch
        self.openSettings = openSettings
        panel.host(RootSearchView(
            model: model,
            onQueryChange: { [weak self] in self?.queryChanged() },
            onMove: { [weak self] delta in self?.move(delta) },
            onRecall: { [weak self] delta in self?.recallHistory(delta) ?? false },
            onSubmit: { [weak self] in self?.activate(self?.model.selection ?? 0) },
            onCancel: { [weak self] in self?.dismiss() },
            onActivate: { [weak self] index in self?.activate(index) },
            onSettings: { [weak self] in self?.dismiss(); openSettings() }
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
        model.showsCopied = false
        calcResult = nil
        rebuildItems()
        model.selection = 0
        model.presentCount += 1
        panel.present(on: PanelScreens.screen(for: settings.panelScreen))
        Signpost.end("root.open", signpost)
    }

    func dismiss() {
        calcTask?.cancel()
        panel.dismiss()
    }

    private func reloadApps() async {
        apps = await appIndex.apps()
        if panel.isVisible { rebuildItems() }
    }

    private func queryChanged() {
        let signpost = Signpost.begin("root.query")
        let query = model.query
        if query == recalledQuery {
            recalledQuery = nil
        } else {
            navigator.reset() // a user edit ends browsing
        }
        calcResult = nil
        rebuildItems()
        model.selection = 0
        Signpost.end("root.query", signpost)

        calcTask?.cancel()
        guard settings.showCalculator, CalculatorGate.looksLikeCalculation(query) else { return }
        calcTask = Task { [calculator] in
            let result = await calculator.evaluate(query)
            guard !Task.isCancelled, model.query == query else { return }
            calcResult = result
            rebuildItems()
            if result != nil { model.selection = 0 }
        }
    }

    /// Calculator card (if any) on top, then apps, with matching commands around them: a command that
    /// matches better than every app ("settings" → Beam Settings) goes above the apps, the rest below.
    /// The calc row never removes app rows.
    private func rebuildItems() {
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

    private func move(_ delta: Int) {
        let count = model.items.count
        guard count > 0 else { return }
        withAnimation(Theme.spring) { model.selection = (model.selection + delta + count) % count }
    }

    private func activate(_ index: Int) {
        guard model.items.indices.contains(index) else { return }
        history.record(model.query, in: .launcher)
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
        case .command(.switchWindows):
            dismiss()
            openWindowSearch()
        case .command(.settings):
            // Open first, while Beam still holds the key panel: macOS only lets an app that the user is
            // interacting with take the front.
            openSettings()
            dismiss()
        }
    }
}
