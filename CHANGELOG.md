# Changelog

All notable changes to Beam are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

## [1.1.0] - 2026-10-23

Every window, one keystroke away.

Beam 1.1 adds Bundles, file search and search history, lets you rebind every global shortcut, and keeps
Accessibility access across updates. Upgrading from 1.0.0: grant Accessibility once more; future updates keep it.

### Added

- **Bundles.** Group the windows and files of one project or task. ⌥ Tab lists bundles first, each with a grey
  count such as "4 windows"; Enter opens the bundle view, and ⌘ Enter brings all of its open windows forward,
  across apps. Press ⌘ G on a highlighted window to add it, or ⇧ ⌘ G in file search to save a search;
  ⌘ ⌫ removes an item. Windows rejoin after a restart through title rules (for example a VS Code window for the
  folder "flagsmith"). Rename, delete and edit rules, files and saved searches in **Settings ▸ Bundles**.
- **File search.** `f <text>` in the launcher, or the **Search Files** command, finds files by name (any word
  order, ignoring case and accents) in the folders you choose. Enter reveals the file in Finder, ⌘ Enter opens it.
  Off by default; turn it on in **Settings ▸ File Search**, where you also pick the folders (Desktop, Documents,
  Downloads, Pictures and iCloud Drive to start with). macOS may ask once for access to those folders when you
  turn it on.
- **Search history.** The launcher and window search each remember your last 100 searches (only ones you used).
  Press ↑ in an empty field to recall them, ↓ to go back. **Settings ▸ Launcher ▸ Clear Search History** empties
  both.
- **Rebindable shortcuts.** **Settings ▸ Shortcuts** changes the Launcher (⌥ Space), Window search (⌥ Tab) and Window
  switcher (⌃ Tab) hotkeys, with a reset for each, and adds optional hotkeys for **Search Files** and **Beam
  Settings**. Beam refuses duplicates, warns about common system shortcuts, and always keeps one way in.
- **Show Beam on.** Choose the screen with the mouse, the screen with the active window, or the primary screen for
  all three panels.
- **Calculator switch.** Turn the launcher's calculator row off in **Settings ▸ Calculator**.
- The tagline on the About pane.

### Changed

- **One Beam at a time.** Opening a second copy shows Settings in the one that is running instead of starting
  another. Opening a newer version replaces the older one, and only a copy in Applications takes over the login
  item.
- **Settings reorganised** into General, Shortcuts, Launcher, Calculator, File Search, Bundles and About.
  Currency-rate status and Refresh moved to Calculator; the Beam Hotkey moved to Shortcuts.
- **Updates keep Accessibility.** Releases are signed with the same self-made certificate every time, so macOS no
  longer forgets the permission after an update. It does not replace the one-time **Open Anyway** step: Beam is
  still not notarized.
- About no longer names the calculator engine.

### For developers

- New pure, tested logic in `BeamCore`: shortcut bindings and validation, search history, file-query parsing,
  bundle rules and matching, title-key extraction, screen choice and the single-instance launch decision
  (223 tests in all).
- The end-to-end suite and README demo now cover history recall, file search and bundles, and no longer need a
  US keyboard layout.
- `Tools/make-signing-cert.sh` creates the release certificate; the release workflow signs with it when the
  secrets are set and falls back to ad-hoc signing for forks.

## [1.0.0] - 2026-10-21

Every window, one keystroke away.

### Highlights

- **⌃ Tab** switches between the windows of the app you're in, across Desktops.
- **⌥ Tab** finds any window by app name or title.
- **⌥ Space** launches apps and answers calculations as you type.
- Panels open in about a millisecond; Beam idles at ~0% CPU and ~45 MB of memory.

### Window switcher (⌃ Tab)

- Lists every window of the frontmost app in most-recently-used order, with your previous window already
  highlighted, so a quick ⌃ Tab flips back and forth like ⌘ Tab does for apps.
- Hold Control and tap Tab (or ⇧ Tab) to move; **release Control to jump** to the highlighted window. Esc cancels
  and Enter jumps immediately.
- Brings back the exact window you pick, including windows on **other Desktops** (Beam switches Desktop for you)
  and **minimized** windows. Badges show "Desktop 2" and "Minimized" at a glance.
- Never lands in the wrong window: a window Beam can't reach is shown greyed out instead.

### Window search (⌥ Tab)

- Searches every window of every app, on every Desktop.
- Match by app name, including nicknames such as `vscode`, `teams` and `chrome`, or by any part of a window
  title, such as `jira` or `invoice`.
- Arrow keys or Tab to select, Enter to go, Esc or a click elsewhere to close.

### Launcher (⌥ Space)

- Fuzzy app search: prefixes (`saf`), word starts (`studio`) and initials (`vsc` → Visual Studio Code).
- Learns which apps you open most and ranks them first.
- Beam commands with friendly aliases: `settings` / `preferences` opens Beam Settings, and `switch windows`
  opens window search. ⌘ , opens Settings from the launcher.
- The hotkey can be rebound in Settings.

### Calculator

- Understands percentages (`5 % of 5000`), arithmetic, units (`65 kg in lb`), currencies
  (`100 usd in eur`), time zones (`3pm london in tokyo`) and dates (`days until dec 25`).
- The answer appears above the app results as you type; Enter copies it.
- Ignores numbers that are just part of an app name, so `Things 3`, `Office 365` and `Xcode 16` launch the app
  instead of "calculating".
- Numbers follow your region's formatting. Currency rates come from the European Central Bank and refresh every
  few hours, with built-in rates as a fallback.

### Settings

- **General:** Open at Login, Show in Menu Bar, Beam Hotkey (with a one-click reset), and Follow System Appearance
  or a fixed Light/Dark look.
- **About:** version, Accessibility status, currency-rate status with a Refresh button, and links.
- Hid the menu-bar icon? Open Beam again from Spotlight or Finder to get back to Settings.

### First run

- Guided Accessibility setup that closes itself the moment access is granted.
- Detects a stale permission entry left by an older copy of Beam and offers a one-click **Reset permission**.
- New app icon and a matching menu-bar icon.

### Reliability and privacy

- Stays responsive when another app hangs: every Accessibility request has a short timeout and runs off the main
  thread.
- The keyboard hook recovers by itself if macOS pauses it, and never leaves a stray Tab or a stuck panel behind.
- No telemetry and no accounts. The only network request is for currency rates.

### Compatibility

- macOS 15 Sequoia or later, as a universal app for Apple silicon and Intel.

### For developers

- Swift 6 with strict concurrency. Pure logic lives in the `BeamKit` package, covered by 107 tests, including
  keystroke-performance budgets.
- An offscreen rendering check and an end-to-end suite that drives the real app.
- GitHub Actions CI on every push and pull request, and a tag-driven release pipeline that builds, checksums and
  drafts the release.
- Build from source with `Tools/install.sh`; an optional `.env` holds your signing team.

[Unreleased]: https://github.com/awaismemon26/beam-macos/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/awaismemon26/beam-macos/releases/tag/v1.1.0
[1.0.0]: https://github.com/awaismemon26/beam-macos/releases/tag/v1.0.0
