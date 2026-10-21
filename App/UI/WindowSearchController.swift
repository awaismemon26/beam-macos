import AppKit
import BeamCore
import SwiftUI

@MainActor @Observable
final class WindowSearchModel {
    var query = "" { didSet { rerank(); selection = 0 } }
    var all: [WindowInfo] = [] { didSet { rerank() } }
    private(set) var results: [WindowInfo] = []
    var selection = 0
    var shakes = 0
    var presentCount = 0
    /// Filled while rows render, so it must not be observed (a write would re-render, forever when an
    /// app has no icon). Misses are cached too.
    @ObservationIgnored private var icons: [pid_t: NSImage?] = [:]

    func icon(for pid: pid_t) -> NSImage? {
        if let cached = icons[pid] { return cached }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
        icons[pid] = .some(icon)
        return icon
    }

    private func rerank() {
        let selectedID = results.indices.contains(selection) ? results[selection].id : nil
        results = WindowSearchRanker.rank(all, query: query)
        // Keep the highlighted window when the list refreshes; reset to the top when the query changes.
        selection = selectedID.flatMap { id in results.firstIndex { $0.id == id } } ?? 0
    }

    func resetSelectionToTop() { selection = 0 }
}

/// Option+Tab: search every window by app name or title.
@MainActor
final class WindowSearchController {
    private let enumerator: WindowEnumerator
    private let activity: WindowActivityMonitor
    private let model = WindowSearchModel()
    private let panel = BeamPanel(size: Theme.rootSize, acceptsKeyboard: true)

    init(enumerator: WindowEnumerator, activity: WindowActivityMonitor) {
        self.enumerator = enumerator
        self.activity = activity
        panel.host(WindowSearchView(
            model: model,
            onMove: { [weak self] delta in self?.move(delta) },
            onSubmit: { [weak self] in self?.activateSelection() },
            onCancel: { [weak self] in self?.dismiss() },
            onActivate: { [weak self] index in self?.activate(index) }
        ))
        panel.onResignKey = { [weak self] in self?.dismiss() }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        guard !panel.isVisible else { return }
        let signpost = Signpost.begin("windowSearch.open")
        model.query = ""
        Task {
            let cached = await enumerator.cachedWindows()
            if model.all.isEmpty { model.all = activity.mru.ordered(cached) }
        }
        model.all = activity.mru.ordered(model.all)
        model.resetSelectionToTop()
        model.presentCount += 1
        panel.present()
        Signpost.end("windowSearch.open", signpost)
        Task {
            let fresh = await enumerator.allWindows()
            model.all = activity.mru.ordered(fresh)
        }
    }

    func dismiss() {
        panel.dismiss()
    }

    private func move(_ delta: Int) {
        let count = model.results.count
        guard count > 0 else { return }
        withAnimation(Theme.spring) { model.selection = (model.selection + delta + count) % count }
    }

    private func activateSelection() {
        activate(model.selection)
    }

    private func activate(_ index: Int) {
        guard model.results.indices.contains(index) else { return }
        model.selection = index
        let window = model.results[index]
        guard window.isReachable else {
            withAnimation(.linear(duration: 0.3)) { model.shakes += 1 }
            return
        }
        Task {
            let element = enumerator.axElement(for: window.id)
            guard element != nil else {
                withAnimation(.linear(duration: 0.3)) { model.shakes += 1 }
                return
            }
            panel.dismiss()
            switch await WindowFocuser.focus(window, element: element) {
            case .focused:
                activity.touch(window.id)
            case .unreachable:
                // Nothing changed on screen: bring the panel back and say so.
                panel.present()
                withAnimation(.linear(duration: 0.3)) { model.shakes += 1 }
            case .mismatch:
                break
            }
        }
    }
}
