// End-to-end tests against the installed, running Beam. They press Beam's real hotkeys, type into its
// panels and read what it draws through the Accessibility API.
//
//   swift Tools/LiveTests/LiveTests.swift
//
// Requirements: Beam running with Accessibility access, the default hotkeys (⌥Space, ⌥Tab, ⌃Tab), a US
// keyboard layout, and Accessibility access for the terminal app running this script. Text is typed only
// after Beam reports its own search field as focused, so keystrokes never land in another app. Each test
// ends with Esc; nothing is switched or launched except Beam's own Settings window, which is closed again.

import AppKit
import ApplicationServices

setbuf(stdout, nil)

// MARK: - Keyboard

private let keyCodes: [Character: (CGKeyCode, Bool)] = {
    var map: [Character: (CGKeyCode, Bool)] = [:]
    let letters: [(Character, CGKeyCode)] = [
        ("a", 0), ("s", 1), ("d", 2), ("f", 3), ("h", 4), ("g", 5), ("z", 6), ("x", 7), ("c", 8), ("v", 9),
        ("b", 11), ("q", 12), ("w", 13), ("e", 14), ("r", 15), ("y", 16), ("t", 17), ("o", 31), ("u", 32),
        ("i", 34), ("p", 35), ("l", 37), ("j", 38), ("k", 40), ("n", 45), ("m", 46),
    ]
    for (ch, code) in letters { map[ch] = (code, false) }
    let digits: [(Character, CGKeyCode)] = [("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23), ("6", 22),
                                            ("7", 26), ("8", 28), ("9", 25), ("0", 29)]
    for (ch, code) in digits { map[ch] = (code, false) }
    map[" "] = (49, false)
    map["%"] = (23, true)
    map["."] = (47, false)
    return map
}()

private enum Key {
    static let tab: CGKeyCode = 48, space: CGKeyCode = 49, returnKey: CGKeyCode = 36, escape: CGKeyCode = 53
    static let control: CGKeyCode = 59
}

private func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(12_000)
}

private func press(_ code: CGKeyCode, flags: CGEventFlags = []) {
    post(code, down: true, flags: flags)
    post(code, down: false, flags: flags)
}

private func type(_ text: String) {
    for ch in text.lowercased() {
        guard let (code, shift) = keyCodes[ch] else { fatalError("no key code for \(ch)") }
        press(code, flags: shift ? .maskShift : [])
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

// MARK: - Beam

guard let beam = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.beam.Beam").first else {
    print("Beam is not running. Install it with Tools/install.sh first.")
    exit(1)
}
guard AXIsProcessTrusted() else {
    print("This terminal needs Accessibility access (System Settings ▸ Privacy & Security ▸ Accessibility).")
    exit(1)
}
private let beamApp = AXUIElementCreateApplication(beam.processIdentifier)

/// Beam's focused text field, when one of its search panels has keyboard focus.
private func beamSearchField() -> AXUIElement? {
    guard let focused = element(attr(beamApp, kAXFocusedUIElementAttribute)),
          (attr(focused, kAXRoleAttribute) as? String) == kAXTextFieldRole else { return nil }
    return focused
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
private let filters = CommandLine.arguments.dropFirst().map { $0.lowercased() }

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
    guard (beamSearchField().flatMap { attr($0, kAXValueAttribute) as? String }) == query else {
        press(Key.escape)
        throw Failure("search field doesn't contain \"\(query)\"")
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

test("Calculator: 5 % of 5000 = 250") {
    let rows = try searchAndRead(Key.space, flags: .maskAlternate, query: "5 % of 5000")
    press(Key.escape)
    guard rows.contains("250") else { throw Failure("no 250 in \(rows)") }
    return ""
}

test("\"settings\" + Enter brings Beam Settings to the front") {
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
    let query = String(name.lowercased().split(separator: " ").first!.filter { keyCodes[$0] != nil })
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

print("\n\(results.count - failures)/\(results.count) passed")
exit(failures == 0 ? 0 : 1)
