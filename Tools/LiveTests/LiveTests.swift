// End-to-end tests against the installed, running Beam. They press Beam's real hotkeys, type into its
// panels and read what it draws through the Accessibility API.
//
//   swift Tools/LiveTests/LiveTests.swift
//
// Requirements: Beam running with Accessibility access, the default hotkeys (⌥Space, ⌥Tab, ⌃Tab), and
// Accessibility access for the terminal app running this script. Any keyboard layout works: text is sent as
// characters, and only keys without a character (Tab, Space as a hotkey, Return, Esc, arrows, Delete) use key
// codes; ⌘G is key code 5 together with the character "g". Text is typed only after Beam reports its own
// search field as focused, so keystrokes never land in another app. Every ⏎ is preceded by a check of what it
// will act on. Each test ends with Esc; nothing is switched or launched except Beam's own Settings window,
// which is closed again.
//
// The history and bundles tests change Beam's history.json and bundles.json. The script backs both up before
// the first such test and, when it ends (also on Ctrl-C, SIGTERM and SIGHUP), quits Beam, puts them back and
// relaunches Beam. If a run was killed hard enough to leave its backup behind, the next run refuses to start
// until `swift Tools/LiveTests/LiveTests.swift --restore` has put the backup back. File search runs only
// while File Search is on in Beam Settings.

import AppKit
import ApplicationServices

setbuf(stdout, nil)

// MARK: - Keyboard

private enum Key {
    static let tab: CGKeyCode = 48, space: CGKeyCode = 49, returnKey: CGKeyCode = 36, escape: CGKeyCode = 53
    static let delete: CGKeyCode = 51, up: CGKeyCode = 126, down: CGKeyCode = 125
    /// The G in ⌘G; the same physical key on US and German layouts.
    static let g: CGKeyCode = 5
    static let control: CGKeyCode = 59
}

/// Set when the script is being stopped by a signal: no more keys are sent while Beam is quit and restored.
private var terminating = false

private func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
    guard !terminating else { return }
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(12_000)
}

private func press(_ code: CGKeyCode, flags: CGEventFlags = []) {
    post(code, down: true, flags: flags)
    post(code, down: false, flags: flags)
}

/// A key that has a character (⌘G): key code and character together, so it works on any layout.
private func press(_ code: CGKeyCode, character: String, flags: CGEventFlags) {
    guard !terminating else { return }
    let units = Array(character.utf16)
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        event.flags = flags
        event.post(tap: .cghidEventTap)
        usleep(12_000)
    }
}

/// Types `text` as characters, whatever the keyboard layout. When Beam's search field is focused, each character
/// is confirmed in the field before the next is sent: a busy Beam (the first calculation after a launch) otherwise
/// drops keystrokes.
private func type(_ text: String) {
    var expected = currentSearchFieldText()
    for character in text where !terminating {
        let units = Array(String(character).utf16)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.flags = []
            event.post(tap: .cghidEventTap)
            usleep(12_000)
        }
        if let before = expected {
            expected = before + String(character)
            let start = Date()
            while currentSearchFieldText() != expected, Date().timeIntervalSince(start) < 1 { usleep(5_000) }
        }
        usleep(15_000)
    }
}

/// Types like a fast typist (~40 ms per character) without waiting for Beam, so a Beam that cannot keep up shows.
private func typeUnconfirmed(_ text: String) {
    for character in text where !terminating {
        let units = Array(String(character).utf16)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.flags = []
            event.post(tap: .cghidEventTap)
            usleep(12_000)
        }
        usleep(15_000)
    }
}

// MARK: - Accessibility

private func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

private func element(_ value: CFTypeRef?) -> AXUIElement? {
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

private func texts(in root: AXUIElement) -> [String] {
    var out: [String] = []
    func walk(_ el: AXUIElement, _ depth: Int) {
        guard depth < 30 else { return }
        if (attr(el, kAXRoleAttribute) as? String) == kAXStaticTextRole, let v = attr(el, kAXValueAttribute) as? String {
            out.append(v)
        }
        for child in (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(child, depth + 1) }
    }
    walk(root, 0)
    return out
}

private func isFrontmost(_ app: NSRunningApplication) -> Bool {
    let el = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(el, 0.3)
    return (attr(el, kAXFrontmostAttribute) as? Bool) == true
}

/// The regular (Dock) app that is frontmost. Background helpers also report AXFrontmost, so only
/// regular apps count.
private func frontmostRegularApp() -> NSRunningApplication? {
    NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.first(where: isFrontmost)
}

// MARK: - The owner's data

private let beamBundleID = "dev.beam.Beam"
private let dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Beam", isDirectory: true)
/// The files the history and bundles tests change.
private let ownedFiles = ["history.json", "bundles.json"]
/// Where the originals are kept while the tests run: each file, or `<name>.absent` when it did not exist, and
/// `complete` once all of them are written. Never overwritten: a leftover one means a run was killed and the
/// files may still be modified.
private let backupDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("beam-livetests-backup", isDirectory: true)
private var backupTaken = false
private let restoreLock = NSLock()
/// Beam's settings as found, compared again at the end.
private let settingKeys = ["fileSearchEnabled", "showInMenuBar"]
private let settingsAtStart = settingKeys.map { CFPreferencesCopyAppValue($0 as CFString, beamBundleID as CFString) as? NSNumber }

private func runningBeams() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: beamBundleID).filter { !$0.isTerminated }
}

private func pollUntil(_ timeout: TimeInterval, _ condition: () -> Bool) {
    let start = Date()
    while !condition(), Date().timeIntervalSince(start) < timeout { Thread.sleep(forTimeInterval: 0.1) }
}

private func hasCompleteBackup() -> Bool {
    FileManager.default.fileExists(atPath: backupDirectory.appendingPathComponent("complete").path)
}

/// Beam keeps history and bundles in memory and rewrites the files, so a test that changes them must be undone
/// by quitting Beam (which flushes), putting the saved files back, and starting Beam again.
private func protectOwnerData() {
    restoreLock.lock()
    defer { restoreLock.unlock() }
    guard !backupTaken else { return }
    // Never overwrite a backup: startup refuses to run while one exists, so this is a safeguard only.
    guard !FileManager.default.fileExists(atPath: backupDirectory.path) else {
        print("A backup from an earlier run is in \(backupDirectory.path); run with --restore first.")
        exit(2)
    }
    do {
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        for name in ownedFiles {
            let source = dataDirectory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: source.path) {
                try Data(contentsOf: source).write(to: backupDirectory.appendingPathComponent(name))
            } else {
                try Data().write(to: backupDirectory.appendingPathComponent(name + ".absent"))
            }
        }
        try Data().write(to: backupDirectory.appendingPathComponent("complete"))
    } catch {
        // Nothing has been changed yet, so a partial backup is simply dropped.
        try? FileManager.default.removeItem(at: backupDirectory)
        print("Could not back up history.json and bundles.json (\(error)); nothing was changed.")
        exit(2)
    }
    backupTaken = true
    print("(history.json and bundles.json are backed up in \(backupDirectory.path); restored when the tests end)")
}

/// Quits Beam (it flushes), puts the backed-up files back (removing the ones that did not exist), deletes the
/// backup and starts Beam again from where it was running.
private func restoreFromBackup() {
    restoreLock.lock()
    defer { restoreLock.unlock() }
    guard hasCompleteBackup() else {
        // An incomplete backup was never followed by a change, so it holds nothing worth keeping.
        try? FileManager.default.removeItem(at: backupDirectory)
        return
    }
    let launchURL = runningBeams().first?.bundleURL ?? URL(fileURLWithPath: "/Applications/Beam.app")
    for app in runningBeams() { app.terminate() }
    pollUntil(8) { runningBeams().isEmpty }
    guard runningBeams().isEmpty else {
        print("Beam did not quit; history.json and bundles.json were NOT restored (backup kept in \(backupDirectory.path); run with --restore)")
        return
    }
    for name in ownedFiles {
        let target = dataDirectory.appendingPathComponent(name)
        let saved = backupDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: saved.path), let data = try? Data(contentsOf: saved) {
            try? data.write(to: target, options: .atomic)
        } else if FileManager.default.fileExists(atPath: backupDirectory.appendingPathComponent(name + ".absent").path) {
            try? FileManager.default.removeItem(at: target)
        }
    }
    try? FileManager.default.removeItem(at: backupDirectory)
    backupTaken = false
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = [launchURL.path]
    try? open.run()
    open.waitUntilExit()
    pollUntil(8) { runningBeams().count == 1 }
    print("Beam restarted with the original history.json and bundles.json (pid \(runningBeams().first?.processIdentifier ?? 0))")
}

private func restoreOwnerData() {
    guard backupTaken else { return }
    restoreFromBackup()
}

atexit { restoreOwnerData() }
// Ctrl-C, `kill`, a closed terminal or a timeout: stop sending keys, restore, leave. The handlers run on a global
// queue because the main thread is usually inside a test.
private var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM, SIGHUP] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
    source.setEventHandler {
        terminating = true
        print("\nStopped by signal \(sig); restoring Beam's data…")
        restoreOwnerData()
        exit(128 + sig)
    }
    source.resume()
    signalSources.append(source)
}

if CommandLine.arguments.contains("--restore") {
    guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
        print("No leftover backup in \(backupDirectory.path); nothing to restore.")
        exit(0)
    }
    restoreFromBackup()
    exit(0)
}
if FileManager.default.fileExists(atPath: backupDirectory.path) {
    print("""
        A backup from an earlier run is still in \(backupDirectory.path).
        That run was stopped before it could put Beam's history.json and bundles.json back, so they may still hold
        its test data. Run `swift Tools/LiveTests/LiveTests.swift --restore` first (it restores them and removes
        the backup), then run the tests again.
        """)
    exit(2)
}

// MARK: - Beam

guard let firstBeam = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.beam.Beam").first else {
    print("Beam is not running. Install it with Tools/install.sh first.")
    exit(1)
}
guard AXIsProcessTrusted() else {
    print("This terminal needs Accessibility access (System Settings ▸ Privacy & Security ▸ Accessibility).")
    exit(1)
}
/// The copy that is running (replaced when a test relaunches Beam) and where it was started from.
private var beam = firstBeam
private var beamApp = AXUIElementCreateApplication(firstBeam.processIdentifier)
private let beamURL = firstBeam.bundleURL ?? URL(fileURLWithPath: "/Applications/Beam.app")

/// Beam's focused text field, when one of its search panels has keyboard focus.
private func beamSearchField() -> AXUIElement? {
    guard let focused = element(attr(beamApp, kAXFocusedUIElementAttribute)),
          (attr(focused, kAXRoleAttribute) as? String) == kAXTextFieldRole else { return nil }
    return focused
}

private func currentSearchFieldText() -> String? {
    beamSearchField().flatMap { attr($0, kAXValueAttribute) as? String }
}

private func waitFor<T>(timeout: TimeInterval, poll: TimeInterval = 0.002, _ check: () -> T?) -> (T, TimeInterval)? {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if let value = check() { return (value, Date().timeIntervalSince(start)) }
        Thread.sleep(forTimeInterval: poll)
    }
    return nil
}

private func beamWindowTexts() -> [String] {
    ((attr(beamApp, kAXWindowsAttribute) as? [AXUIElement]) ?? []).flatMap(texts(in:))
}

private func closeBeamSettings() {
    for window in (attr(beamApp, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    where (attr(window, kAXTitleAttribute) as? String) == "Beam Settings" {
        if let close = element(attr(window, kAXCloseButtonAttribute)) {
            AXUIElementPerformAction(close, kAXPressAction as CFString)
        }
    }
    usleep(300_000)
}

// MARK: - Runner

private var failures = 0
private var results: [String] = []

/// Optional filters: `swift Tools/LiveTests/LiveTests.swift settings switcher` runs only matching tests.
private let filters = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }.map { $0.lowercased() }

private func test(_ name: String, _ body: () throws -> String) {
    guard filters.isEmpty || filters.contains(where: name.lowercased().contains) else { return }
    do {
        let detail = try body()
        results.append("✔ \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    } catch {
        failures += 1
        results.append("✘ \(name) — \(error)")
    }
    print(results.last!)
}

private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Opens a search panel with `hotkey` and returns the focus latency, or throws without typing anything.
private func openSearchPanel(_ code: CGKeyCode, flags: CGEventFlags) throws -> TimeInterval {
    press(code, flags: flags)
    guard let (_, latency) = waitFor(timeout: 1.0, { beamSearchField() }) else {
        press(Key.escape)
        throw Failure("panel didn't get keyboard focus within 1 s; nothing was typed")
    }
    return latency
}

private func searchAndRead(_ code: CGKeyCode, flags: CGEventFlags, query: String, settle: TimeInterval = 0.5) throws -> [String] {
    _ = try openSearchPanel(code, flags: flags)
    type(query)
    Thread.sleep(forTimeInterval: settle)
    let typed = beamSearchField().flatMap { attr($0, kAXValueAttribute) as? String }
    guard typed == query else {
        press(Key.escape)
        throw Failure("search field has \(typed.map { "\"\($0)\"" } ?? "no text") instead of \"\(query)\"")
    }
    return beamWindowTexts()
}

closeBeamSettings()
// The first AX request makes Beam build its accessibility tree; do it now so it isn't timed.
_ = beamWindowTexts()
print("Beam \(beam.bundleURL?.path ?? "?") (pid \(beam.processIdentifier))\n")

test("Launcher opens with focus (⌥Space)") {
    var latencies: [TimeInterval] = []
    for _ in 0..<5 {
        latencies.append(try openSearchPanel(Key.space, flags: .maskAlternate))
        press(Key.escape)
        usleep(250_000)
    }
    let ms = latencies.map { Int(($0 * 1000).rounded()) }
    return "hotkey → focused field: \(ms.map(String.init).joined(separator: ", ")) ms (incl. AX polling)"
}

test("Cold start: typing right after launch drops no keystrokes") {
    // Quit Beam (it flushes), start it again and type into the launcher the moment it opens, at typing speed and
    // without confirming characters: AppKit queues keys for a busy app, so none may be lost.
    for app in runningBeams() { app.terminate() }
    pollUntil(8) { runningBeams().isEmpty }
    guard runningBeams().isEmpty else { throw Failure("Beam did not quit") }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = [beamURL.path]
    try open.run()
    open.waitUntilExit()
    pollUntil(8) { runningBeams().count == 1 }
    guard let fresh = runningBeams().first else { throw Failure("Beam did not start") }
    beam = fresh
    beamApp = AXUIElementCreateApplication(fresh.processIdentifier)
    _ = beamWindowTexts() // the first AX request builds Beam's accessibility tree; keep it out of the typing
    // The hotkey is registered a moment after launch; a press before that would reach the frontmost app, so wait,
    // press once, and fail rather than press again.
    Thread.sleep(forTimeInterval: 2)
    press(Key.space, flags: .maskAlternate)
    guard waitFor(timeout: 3, { beamSearchField() }) != nil else {
        throw Failure("the launcher didn't open within 3 s of the hotkey, 2 s after launch")
    }
    let query = "5 % of 5000"
    typeUnconfirmed(query)
    Thread.sleep(forTimeInterval: 0.8)
    let typed = currentSearchFieldText()
    let rows = beamWindowTexts()
    press(Key.escape)
    guard typed == query else { throw Failure("typed \"\(query)\", the field has \(typed.map { "\"\($0)\"" } ?? "no text")") }
    guard rows.contains("250") else { throw Failure("no 250 in \(rows)") }
    return "\"\(query)\" arrived intact right after launch"
}

test("Calculator: 5 % of 5000 = 250") {
    let rows = try searchAndRead(Key.space, flags: .maskAlternate, query: "5 % of 5000")
    press(Key.escape)
    guard rows.contains("250") else { throw Failure("no 250 in \(rows)") }
    return ""
}

test("\"settings\" + Enter brings Beam Settings to the front") {
    protectOwnerData() // ⏎ records "settings" in the launcher history
    let previous = frontmostRegularApp()
    let rows = try searchAndRead(Key.space, flags: .maskAlternate, query: "settings")
    guard let first = rows.first, first == "Beam Settings" else {
        press(Key.escape)
        throw Failure("first row is \(rows.first ?? "nothing"), expected Beam Settings")
    }
    press(Key.returnKey)
    defer { closeBeamSettings() }
    // Only Beam and the app that was in front are queried, so each poll is quick.
    guard let (_, latency) = waitFor(timeout: 1.5, poll: 0.005, { () -> Bool? in
        let focusedTitle = element(attr(beamApp, kAXFocusedWindowAttribute)).flatMap { attr($0, kAXTitleAttribute) as? String }
        let previousLostFront = previous.map { !isFrontmost($0) } ?? true
        return isFrontmost(beam) && previousLostFront && focusedTitle == "Beam Settings" ? true : nil
    }) else {
        throw Failure("Beam Settings isn't the focused window of the frontmost app (front: \(frontmostRegularApp()?.localizedName ?? "Beam?"))")
    }
    return "in front with focus after \(Int(latency * 1000)) ms"
}

test("Window search (⌥Tab) filters by app name") {
    // Pick the regular app with the most windows, and search for the first word of its name.
    let candidates = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != beam }
    let counted = candidates.map { app -> (NSRunningApplication, Int) in
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.3)
        return (app, (attr(el, kAXWindowsAttribute) as? [AXUIElement])?.count ?? 0)
    }
    guard let (target, count) = counted.filter({ $0.1 > 0 && ($0.0.localizedName ?? "").first?.isLetter == true })
        .max(by: { $0.1 < $1.1 }) else { throw Failure("no app with windows to search for") }
    let name = target.localizedName!
    let query = String(name.lowercased().split(separator: " ").first!.filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    let rows = try searchAndRead(Key.tab, flags: .maskAlternate, query: query)
    press(Key.escape)
    guard let footer = rows.first(where: { $0.hasSuffix("windows") || $0.hasSuffix("window") }),
          let shown = Int(footer.split(separator: " ").first ?? "") else { throw Failure("no window count in \(rows)") }
    guard shown >= 1, rows.contains(name) else { throw Failure("\"\(query)\" showed \(footer) without \(name) rows: \(rows)") }
    return "\"\(query)\" → \(footer) (\(name) has \(count) AX windows)"
}

test("Switcher (⌃Tab) shows the frontmost app; Esc cancels") {
    // Bring a regular app with windows to the front (an earlier test may have left Beam active).
    if frontmostRegularApp() == nil,
       let app = NSWorkspace.shared.runningApplications.first(where: { app in
           app.activationPolicy == .regular && app != beam
               && ((attr(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute) as? [AXUIElement])?.isEmpty == false)
       }), let id = app.bundleIdentifier {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-b", id]
        try open.run()
        open.waitUntilExit()
        _ = waitFor(timeout: 2, poll: 0.05) { frontmostRegularApp() }
    }
    guard let front = frontmostRegularApp(), let name = front.localizedName else { throw Failure("no frontmost app") }
    post(Key.control, down: true, flags: .maskControl)
    press(Key.tab, flags: .maskControl)
    defer { post(Key.control, down: false) }
    guard let (rows, latency) = waitFor(timeout: 1.0, poll: 0.005, { () -> [String]? in
        let rows = beamWindowTexts()
        return rows.contains(name) ? rows : nil
    }) else {
        press(Key.escape, flags: .maskControl)
        throw Failure("switcher didn't show \(name)")
    }
    press(Key.escape, flags: .maskControl)
    post(Key.control, down: false)
    usleep(300_000)
    guard frontmostRegularApp() == front else { throw Failure("Esc switched away from \(name)") }
    let count = rows.first { $0.hasSuffix("windows") || $0.hasSuffix("window") } ?? "?"
    return "\(name), \(count), visible after \(Int(latency * 1000)) ms; focus unchanged after Esc"
}

test("History: Esc doesn't record, ⏎ records, ↑ recalls") {
    protectOwnerData()
    func field() -> String? { beamSearchField().flatMap { attr($0, kAXValueAttribute) as? String } }
    // "prefer" is not in the history: closing with Esc must not add it.
    _ = try searchAndRead(Key.space, flags: .maskAlternate, query: "prefer")
    press(Key.escape)
    usleep(300_000)
    _ = try openSearchPanel(Key.space, flags: .maskAlternate)
    press(Key.up)
    usleep(250_000)
    let afterEsc = field()
    press(Key.escape)
    usleep(300_000)
    guard afterEsc != "prefer" else { throw Failure("Esc recorded \"prefer\"") }
    // ⏎ on the Beam Settings command (an alias, so the query is unique) records the query.
    let rows = try searchAndRead(Key.space, flags: .maskAlternate, query: "preferences")
    // ⏎ activates the first row: it must be the Beam Settings command, never an app.
    guard rows.first == "Beam Settings" else {
        press(Key.escape)
        throw Failure("\"preferences\": the first row is \(rows.first.map { "\"\($0)\"" } ?? "missing"), not Beam Settings; ⏎ not pressed")
    }
    press(Key.returnKey)
    usleep(500_000)
    closeBeamSettings()
    _ = try openSearchPanel(Key.space, flags: .maskAlternate)
    press(Key.up)
    usleep(250_000)
    let recalled = field()
    press(Key.down)
    usleep(250_000)
    let afterDown = field()
    press(Key.escape)
    guard recalled == "preferences" else { throw Failure("↑ recalled \(recalled.map { "\"\($0)\"" } ?? "nothing"), expected \"preferences\"") }
    guard afterDown == "" else { throw Failure("↓ past the newest entry left \(afterDown.map { "\"\($0)\"" } ?? "no field")") }
    return "Esc left no entry; ⏎ recorded; ↑ recalled it; ↓ emptied the field"
}

test("Single instance: open -n hands over to the running Beam") {
    let before = runningBeams().map(\.processIdentifier)
    guard before.count == 1 else { throw Failure("expected one Beam before, found \(before.count)") }
    defer { closeBeamSettings() }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-n", beamURL.path]
    try open.run()
    open.waitUntilExit()
    // The running copy shows Settings when the second one hands over to it.
    guard waitFor(timeout: 8, poll: 0.1, { () -> Bool? in
        let titles = ((attr(beamApp, kAXWindowsAttribute) as? [AXUIElement]) ?? []).map { attr($0, kAXTitleAttribute) as? String }
        return titles.contains("Beam Settings") ? true : nil
    }) != nil else { throw Failure("the running Beam didn't show Settings after the hand-over") }
    guard waitFor(timeout: 5, poll: 0.1, { runningBeams().count == 1 ? true : nil }) != nil else {
        throw Failure("\(runningBeams().count) Beams are running")
    }
    usleep(500_000) // a late second copy would show up now
    let after = runningBeams().map(\.processIdentifier)
    guard after == before else { throw Failure("Beam pids \(before) → \(after)") }
    return "still one Beam (pid \(after[0])), Settings shown by the hand-over"
}

test("File search: `f pdf` lists files; Search Files is a command") {
    let enabled = (CFPreferencesCopyAppValue("fileSearchEnabled" as CFString, beamBundleID as CFString) as? NSNumber)?.boolValue ?? false
    guard enabled else { return "skipped — File Search is off in Beam Settings" }
    // Only that rows appear is checked; ⏎ would open a Finder window.
    _ = try openSearchPanel(Key.space, flags: .maskAlternate)
    type("f pdf")
    guard let (rows, latency) = waitFor(timeout: 4, poll: 0.05, { () -> [String]? in
        let rows = beamWindowTexts()
        return rows.contains("Files") && rows.contains(where: { $0.lowercased().hasSuffix(".pdf") }) ? rows : nil
    }) else {
        let seen = beamWindowTexts().count
        press(Key.escape)
        throw Failure("no \"Files\" section with .pdf rows after 4 s (\(seen) texts on screen); is Spotlight indexing?")
    }
    press(Key.escape)
    usleep(300_000)
    let commandRows = try searchAndRead(Key.space, flags: .maskAlternate, query: "search files")
    press(Key.escape)
    guard commandRows.contains("Search Files") else { throw Failure("no Search Files command in \(commandRows)") }
    return "\(rows.filter { $0.lowercased().hasSuffix(".pdf") }.count) .pdf rows after \(Int(latency * 1000)) ms; Search Files command listed"
}

test("Bundles: ⌘G adds a window, ⌥Tab shows \"1 window\", ⌘⌫ removes it") {
    protectOwnerData()
    // A regular app whose windows have no document title key (browsers, terminals…), so the rule matches exactly the
    // one window; Finder and the like would match every window with the same title.
    let keyed: Set<String> = ["com.apple.finder", "com.apple.dt.Xcode", "com.apple.Preview", "com.apple.TextEdit",
                              "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.microsoft.Excel",
                              "com.microsoft.Powerpoint", "com.microsoft.Word"]
    let candidates = NSWorkspace.shared.runningApplications.filter {
        $0.activationPolicy == .regular && $0 != beam && !keyed.contains($0.bundleIdentifier ?? "")
            && ($0.localizedName ?? "").first?.isLetter == true
    }
    let withWindows = candidates.filter { app in
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.3)
        return ((attr(el, kAXWindowsAttribute) as? [AXUIElement])?.isEmpty == false)
    }
    guard let target = withWindows.first, let name = target.localizedName else { throw Failure("no suitable app with windows") }
    let query = String(name.split(separator: " ").first!.filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    let bundleName = "Zz Livetest"

    // ⌘G on the first matching window, then name a new bundle and ⏎.
    var rows = try searchAndRead(Key.tab, flags: .maskAlternate, query: query)
    guard rows.contains(name) else { press(Key.escape); throw Failure("\"\(query)\" listed no \(name) window") }
    press(Key.g, character: "g", flags: .maskCommand)
    guard waitFor(timeout: 1.5, poll: 0.02, { beamWindowTexts().contains { $0.hasPrefix("Add “") } ? true : nil }) != nil else {
        press(Key.escape)
        throw Failure("⌘G didn't open the bundle picker")
    }
    type(bundleName)
    // The new-bundle row is the selected one when no existing bundle matches the name, i.e. when it directly follows
    // the picker's caption. Anything else (a bundle of the owner's) and ⏎ would add the window to the wrong bundle.
    let newRow = "New bundle “\(bundleName)”"
    guard waitFor(timeout: 1.5, poll: 0.02, { () -> Bool? in
        let texts = beamWindowTexts()
        guard let caption = texts.firstIndex(where: { $0.hasPrefix("Add “") }), texts.indices.contains(caption + 1) else { return nil }
        return texts[caption + 1] == newRow ? true : nil
    }) != nil else {
        press(Key.escape)
        press(Key.escape)
        throw Failure("the picker's first row isn't \"\(newRow)\"; ⏎ not pressed")
    }
    press(Key.returnKey)
    usleep(400_000)
    press(Key.escape)
    usleep(300_000)

    // The bundle row says "1 window".
    rows = try searchAndRead(Key.tab, flags: .maskAlternate, query: bundleName.lowercased())
    guard rows.contains(bundleName), rows.contains("1 window") else {
        press(Key.escape)
        throw Failure("no \"\(bundleName)\" row with \"1 window\" in \(rows)")
    }

    // ⏎ opens the bundle view. It is the selected row only when it is the one and only match (no Windows section).
    guard rows.first == bundleName, !rows.contains("Windows") else {
        press(Key.escape)
        throw Failure("\"\(bundleName)\" isn't the only match (\(rows.count) texts, first \(rows.first.map { "\"\($0)\"" } ?? "missing")); ⏎ not pressed")
    }
    press(Key.returnKey)
    guard waitFor(timeout: 1.5, poll: 0.02, { () -> Bool? in
        let texts = beamWindowTexts()
        return texts.contains(name) && texts.contains { $0.contains("⌘⌫ remove") } ? true : nil
    }) != nil else {
        press(Key.escape)
        press(Key.escape)
        throw Failure("bundle view didn't list the \(name) window")
    }
    press(Key.delete, flags: .maskCommand)
    guard waitFor(timeout: 1.5, poll: 0.02, { beamWindowTexts().contains { $0.hasPrefix("No open windows") } ? true : nil }) != nil else {
        press(Key.escape)
        press(Key.escape)
        throw Failure("⌘⌫ didn't empty the bundle view")
    }
    press(Key.escape) // back to the list: the bundle now has no open windows
    guard waitFor(timeout: 1.5, poll: 0.02, { beamWindowTexts().contains("no open windows") ? true : nil }) != nil else {
        press(Key.escape)
        throw Failure("the bundle row doesn't say \"no open windows\" after ⌘⌫")
    }
    press(Key.escape)
    return "\(name) window → \"1 window\" → removed → \"no open windows\" (bundle deleted when the saved files are restored)"
}

test("Idle resource use") {
    Thread.sleep(forTimeInterval: 3)
    // CPU time used over 5 idle seconds, and the memory footprint macOS charges Beam (what Activity
    // Monitor shows as "Memory"), via proc_pid_rusage.
    func usage() throws -> rusage_info_v4 {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(beam.processIdentifier, RUSAGE_INFO_V4, $0) }
        }
        guard ok == 0 else { throw Failure("proc_pid_rusage failed") }
        return info
    }
    let before = try usage()
    Thread.sleep(forTimeInterval: 5)
    let after = try usage()
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let cpuNanos = Double((after.ri_user_time + after.ri_system_time) - (before.ri_user_time + before.ri_system_time))
        * Double(timebase.numer) / Double(timebase.denom)
    let cpuPercent = cpuNanos / 5e9 * 100
    let footprintMB = Double(after.ri_phys_footprint) / 1_048_576
    guard cpuPercent < 1.0 else { throw Failure(String(format: "idle CPU %.2f%%", cpuPercent)) }
    guard footprintMB < 60 else { throw Failure(String(format: "memory footprint %.0f MB (budget 60 MB)", footprintMB)) }
    return String(format: "CPU %.2f%% over 5 s, memory footprint %.0f MB", cpuPercent, footprintMB)
}

restoreOwnerData()
let settingsAtEnd = settingKeys.map { CFPreferencesCopyAppValue($0 as CFString, beamBundleID as CFString) as? NSNumber }
if settingsAtEnd != settingsAtStart {
    failures += 1
    print("✘ Beam settings changed during the run: \(settingsAtStart) → \(settingsAtEnd)")
}
print("\n\(results.count - failures)/\(results.count) passed")
exit(failures == 0 ? 0 : 1)
