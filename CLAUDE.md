# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Beam is a native macOS window switcher and launcher (Swift 6, SwiftUI + AppKit, macOS 15+, universal build):
⌃Tab switches windows of the current app, ⌥Tab searches all windows and Bundles, ⌥Space is the launcher with
calculator and file search.

## Commands

```bash
brew install xcodegen                      # once; Beam.xcodeproj is generated from project.yml and git-ignored
Tools/generate.sh                          # generate Beam.xcodeproj (reads BEAM_TEAM_ID from .env)
Tools/install.sh                           # Release build → /Applications/Beam.app, relaunches Beam
(cd Packages/BeamKit && swift test)        # all unit tests (Swift Testing)
(cd Packages/BeamKit && swift test --filter TitleKeyTests)   # one suite; append /<testName> for one test
Tools/RenderCheck/run.sh                   # renders the ⌥Tab view offscreen and checks rows via OCR (no permissions)
swift Tools/LiveTests/LiveTests.swift      # end-to-end against the installed, running Beam (see below)
Tools/Demo/run.sh                          # regenerate assets/demo.gif after UI changes
Tools/build-release.sh 1.2.0               # dist/Beam-1.2.0.zip + .sha256, the same build CI and releases use
```

- Edit `project.yml`, never the generated project. The version lives in `MARKETING_VERSION` there.
- The build must stay warning-free: Swift 6 language mode with complete strict concurrency.
- After moving the checkout, delete `Packages/BeamKit/.build` and `build/`; both cache absolute paths.
- `.env` (git-ignored, from `.env.example`) sets `BEAM_TEAM_ID`. Without it, builds are ad-hoc signed and macOS asks
  for Accessibility again after every rebuild.

## Architecture

**Two layers.** `Packages/BeamKit/Sources/BeamCore` holds all pure logic: no AppKit, no AX, fully unit-tested.
Examples are hotkey classification, the switcher state machine, fuzzy matching and ranking, bundle matching, title
keys, search history and shortcut bindings. `BeamCalc` wraps the SoulverCore calculator engine. `App/` is the macOS
app: `App/System` holds OS integration, `App/UI` holds panels, controllers and SwiftUI views. New logic that can be
tested without a window belongs in BeamCore, with tests in `Packages/BeamKit/Tests`.

**Composition root.** `App/AppDelegate.swift` owns every long-lived service. Startup runs in this order:

1. `SingleInstance.resolve()` keeps exactly one Beam running. A newer version replaces an older one.
2. The stores and the launcher (`RootSearchController`) start. They need no permission.
3. Once Accessibility is granted, `startServices()` starts the AX-dependent parts: window enumeration, the activity
   monitor, the event tap, and the switcher and window-search controllers.

**Hotkey path.**
- `EventTap` is a session-level CGEvent tap on its own high-priority thread.
- It asks `HotkeyClassifier` (BeamCore) whether a key event is one of Beam's bindings. It swallows exactly those
  and hops to the main actor with a `HotkeyAction`. Everything else passes through.
- The tap callback must never block: no AX calls, no awaiting.
- `AppDelegate.perform` routes each action to a controller.
- Bindings come from `AppSettings.activeShortcuts` and update live when changed in Settings.

**Windows.**
- `WindowEnumerator` (an actor with a per-app cache) joins each app's Accessibility window list with window-server
  data from the private APIs in `PrivateAPIs.swift` (resolved via `dlsym`), so windows on other Desktops and
  minimized windows are included.
- `WindowActivityMonitor` keeps the MRU order through AXObservers and NSWorkspace, with no polling, and invalidates
  the enumerator's cache per pid.
- `WindowFocuser` brings one exact window forward: a SkyLight front-process call, a synthetic make-key event, then
  an AX raise.
- When a private symbol is missing, or a window can't be focused reliably, it is greyed out ("Can't reach this
  window"). Never fall back to focusing a different window of the app.
- Every AX call has a 0.25 s messaging timeout and stays off the main thread.

**Panels.**
- `BeamPanel` is a borderless, non-activating `NSPanel`, built once and then only shown or hidden.
- Each feature has a controller in `App/UI`: `SwitcherController` (⌃Tab, driven by `SwitcherStateMachine`),
  `WindowSearchController` (⌥Tab) and `RootSearchController` (⌥Space).
- Each controller has a mode enum (root / bundle / files / picker) and hosts a SwiftUI view.
- `PanelScreens` picks the display from the "Show Beam on" setting.

**Persistence.**
- Preferences live in `UserDefaults` (`AppSettings`).
- User data is JSON in `~/Library/Application Support/Beam/`: `history.json` (HistoryStore), `bundles.json`
  (BundleStore) and `usage.json` (UsageStore). Saves are debounced and flushed in `applicationWillTerminate`.

**Bundles.**
- A bundle holds window rules, files and saved file searches.
- A rule names an app plus a *title key* (`TitleKey.swift`), meaning the document or folder name taken from the
  window title. That is how windows of VS Code, Office, Preview and Finder rejoin a bundle after a restart.
- Windows without a stable title key belong to the bundle for the current session only.

**File search.** `FileSearcher` runs a Spotlight `NSMetadataQuery` on names only, in the folders the user chose. It
is off by default, and only one query is live at a time.

## Test tooling details

- `Tools/RenderCheck/run.sh` and `Tools/Demo/run.sh` compile BeamCore sources and selected `App/UI` files together
  with `swiftc`, after stripping `import BeamCore`. Those UI files (listed in each script) must compile without the
  rest of the app. In `WindowSearchController.swift`, only the model part above the controller's doc comment is
  copied.
- LiveTests press Beam's real hotkeys, so they need Beam running with the default shortcuts and Accessibility for
  the terminal. They back up and restore `history.json` and `bundles.json`. After an interrupted run, use
  `--restore`. They work on any keyboard layout.
- Use generic sample data in tests and fixtures (`my-project`, `acme-api`, `deploy.yml`, Apple's apps), never
  real paths, usernames or window titles.

## Releases and signing

- Releases are built ad-hoc, then re-signed with a self-made certificate named "Beam" (`Tools/make-signing-cert.sh`).
  Every release then has the same designated requirement, so updates keep the Accessibility permission.
- In CI, `release.yml` imports the certificate from the secrets `BEAM_SIGNING_P12_BASE64` and
  `BEAM_SIGNING_P12_PASSWORD`. It fails on purpose in this repository when they are missing; forks build ad-hoc.
- To release: move the `[Unreleased]` CHANGELOG notes under a version heading, then push a `vX.Y.Z` tag. The Release
  workflow builds and creates a **draft** release, using notes from `Tools/release-notes.sh`.
- Local team-signed builds and release builds are different identities to macOS. Switching between them needs
  Accessibility granted again.

## Conventions

- Public docs (README, CHANGELOG, About pane) stay short and user-facing. They never name the calculator engine and
  carry no developer detail; developer detail goes in CONTRIBUTING.md.
- `docs/` (specs, plans, `KNOWN_LIMITS.md`) and `.superpowers/` are local-only and git-ignored.
- When testing on this machine, quit or relaunch only Beam, never other apps. Leave Beam's settings as you found
  them. Don't reset TCC permissions.
