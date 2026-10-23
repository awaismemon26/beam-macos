import AppKit
import BeamCore
import SwiftUI

/// The bundles and, for one chosen bundle, its name, window rules, files and saved searches.
struct BundlesSettings: View {
    let store: BundleStore
    let settings: AppSettings
    @State private var selected: UUID?

    var body: some View {
        if let selected, store.bundle(selected) != nil {
            BundleDetail(store: store, settings: settings, id: selected) { self.selected = nil }
        } else {
            list
        }
    }

    @ViewBuilder
    private var list: some View {
        if store.bundles.isEmpty {
            SettingsCard {
                Text("Group the windows and files of one project or task. In ⌥ Tab, highlight a window and press ⌘ G.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
            }
        } else {
            SettingsCard {
                ForEach(Array(store.bundles.enumerated()), id: \.element.id) { index, bundle in
                    if index > 0 { SettingsDivider() }
                    Button { selected = bundle.id } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(bundle.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 16)
                            Text(Self.counts(bundle))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// "2 rules, 3 files, 1 saved search"; "empty" for a bundle with nothing in it.
    static func counts(_ bundle: BeamBundle) -> String {
        func part(_ count: Int, _ singular: String, _ plural: String) -> String? {
            count == 0 ? nil : "\(count) " + (count == 1 ? singular : plural)
        }
        let parts = [part(bundle.rules.count, "rule", "rules"), part(bundle.files.count, "file", "files"),
                     part(bundle.savedSearches.count, "saved search", "saved searches")]
        let text = parts.compactMap { $0 }.joined(separator: ", ")
        return text.isEmpty ? "empty" : text
    }
}

// MARK: - One bundle

private struct BundleDetail: View {
    let store: BundleStore
    let settings: AppSettings
    let id: UUID
    let onBack: () -> Void

    @State private var name: String
    @State private var newSearch = ""
    @State private var confirmsDelete = false
    @State private var runningApps = RunningApp.current()
    @FocusState private var nameFocused: Bool

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    init(store: BundleStore, settings: AppSettings, id: UUID, onBack: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.id = id
        self.onBack = onBack
        _name = State(initialValue: store.bundle(id)?.name ?? "")
    }

    private var bundle: BeamBundle? { store.bundle(id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Label("Bundles", systemImage: "chevron.left")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.bottom, 12)

            SettingsCard {
                SettingsRow("Name") {
                    TextField("Bundle name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 240)
                        .focused($nameFocused)
                        .onSubmit(commitName)
                }
            }
            .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
            .onDisappear(perform: commitName)

            SettingsSectionHeader("Windows")
            SettingsCard {
                let rules = bundle?.rules ?? []
                ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                    if index > 0 { SettingsDivider() }
                    ruleRow(rule, at: index)
                }
                if !rules.isEmpty { SettingsDivider() }
                addButton("Add Rule", help: "A window matches a rule when its app and title fit it.") {
                    store.setRules(rules + [BundleRule(appBundleID: nil, key: "", match: .contains)], for: id)
                }
            }

            SettingsSectionHeader("Files")
            SettingsCard {
                let files = bundle?.files ?? []
                ForEach(Array(files.enumerated()), id: \.element) { index, path in
                    if index > 0 { SettingsDivider() }
                    fileRow(path)
                }
                if !files.isEmpty { SettingsDivider() }
                addButton("Add Files…", help: "Choose files to keep in this bundle.", action: addFiles)
            }

            SettingsSectionHeader("Saved Searches")
            SettingsCard {
                let searches = bundle?.savedSearches ?? []
                ForEach(Array(searches.enumerated()), id: \.element) { index, search in
                    if index > 0 { SettingsDivider() }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary).frame(width: 20)
                        Text(search).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 16)
                        RemoveButton(help: "Remove this search") { store.removeSavedSearch(search, from: id) }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                }
                if !searches.isEmpty { SettingsDivider() }
                HStack(spacing: 10) {
                    TextField("File name words, e.g. invoice march", text: $newSearch)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSearch)
                    Button(action: addSearch) { Label("Add", systemImage: "plus") }
                        .disabled(newSearch.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
            }
            Text("A saved search lists the files whose names contain all its words, within the File Search folders.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.leading, 4)

            Button("Delete Bundle…", role: .destructive) { confirmsDelete = true }
                .padding(.top, 24)
                .padding(.leading, 4)
        }
        .alert("Delete “\(bundle?.name ?? name)”?", isPresented: $confirmsDelete) {
            Button("Delete", role: .destructive) {
                store.delete(id)
                onBack()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The bundle is removed. Your windows and files are not touched.")
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            name = bundle?.name ?? name // a bundle needs a name
        } else {
            store.rename(id, to: trimmed)
            name = trimmed
        }
    }

    // MARK: Rules

    private func edit(_ index: Int, _ change: (inout BundleRule) -> Void) {
        guard var rules = bundle?.rules, rules.indices.contains(index) else { return }
        change(&rules[index])
        store.setRules(rules, for: id)
    }

    @ViewBuilder
    private func ruleRow(_ rule: BundleRule, at index: Int) -> some View {
        HStack(spacing: 8) {
            if rule.sessionWindowID != nil {
                Text(RunningApp.name(of: rule.appBundleID))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .frame(width: 130, alignment: .leading)
                Text(rule.key)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text("This session only")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Picker("", selection: Binding(
                    get: { rule.appBundleID },
                    set: { app in edit(index) { $0.appBundleID = app } }
                )) {
                    Text("Any app").tag(String?.none)
                    Divider()
                    ForEach(appOptions(including: rule.appBundleID)) { app in Text(app.name).tag(String?.some(app.id)) }
                }
                .labelsHidden()
                .frame(width: 130)
                TextField("Title text", text: Binding(
                    get: { rule.key },
                    set: { text in edit(index) { $0.key = text } }
                ))
                .textFieldStyle(.roundedBorder)
                Picker("", selection: Binding(
                    get: { rule.match },
                    set: { match in edit(index) { $0.match = match } }
                )) {
                    Text("Exact title key").tag(BundleRule.Match.exact)
                    Text("Title contains").tag(BundleRule.Match.contains)
                }
                .labelsHidden()
                .frame(width: 130)
            }
            RemoveButton(help: "Remove this rule") {
                guard var rules = bundle?.rules, rules.indices.contains(index) else { return }
                rules.remove(at: index)
                store.setRules(rules, for: id)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }

    /// The running apps, plus the rule's own app when it isn't running.
    private func appOptions(including bundleID: String?) -> [RunningApp] {
        guard let bundleID, !runningApps.contains(where: { $0.id == bundleID }) else { return runningApps }
        return runningApps + [RunningApp(id: bundleID, name: RunningApp.name(of: bundleID))]
    }

    // MARK: Files and searches

    private func fileRow(_ path: String) -> some View {
        let exists = FileManager.default.fileExists(atPath: path)
        return HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 20, height: 20)
            Text((path as NSString).lastPathComponent)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
            Spacer(minLength: 12)
            Text(exists ? FilePaths.display(FilePaths.folder(of: path), home: Self.home) : "Missing")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            RemoveButton(help: "Remove this file from the bundle") { store.removeFile(path, from: id) }
        }
        .opacity(exists ? 1 : 0.5)
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    private func addButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) { Label(title, systemImage: "plus") }.help(help)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose files for this bundle."
        panel.begin { [store, id] response in
            guard response == .OK else { return }
            MainActor.assumeIsolated {
                for url in panel.urls { store.addFile(url.path, to: id) }
            }
        }
    }

    private func addSearch() {
        let text = newSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addSavedSearch(FileQuery.prefixedTerms(text) ?? text, to: id) // a typed `f ` prefix is not part of it
        newSearch = ""
        // The bundle view runs saved searches even while File Search is off, and macOS has then never been asked
        // for folder access: ask now, while the user is in Settings, not when the bundle opens (a prompt takes
        // focus and would close the panel). With File Search on, turning it on already asked.
        if !settings.fileSearchEnabled { FileSearcher.touchScopes(settings.fileScopes) }
    }
}

// MARK: - Pieces

/// A running app a rule can name.
private struct RunningApp: Identifiable, Hashable {
    let id: String // bundle ID
    let name: String

    /// Regular (Dock) apps that are running now, by name.
    static func current() -> [RunningApp] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, let name = app.localizedName, seen.insert(id).inserted else { return nil }
                return RunningApp(id: id, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The installed app's name, else the bundle ID itself.
    static func name(of bundleID: String?) -> String {
        guard let bundleID else { return "Any app" }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return url.deletingPathExtension().lastPathComponent
    }
}

private struct RemoveButton: View {
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
