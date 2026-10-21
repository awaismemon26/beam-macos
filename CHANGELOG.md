# Changelog

All notable changes to Beam are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

## [1.0.0] - 2026-10-21

The first release of Beam: a fast, native window switcher and launcher for macOS, built entirely in Swift,
SwiftUI and AppKit, with no web views and no Electron.

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

- Powered by SoulverCore: percentages (`5 % of 5000`), arithmetic, units (`65 kg in lb`), currencies
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

[Unreleased]: https://github.com/awaismemon26/beam/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/awaismemon26/beam/releases/tag/v1.0.0
