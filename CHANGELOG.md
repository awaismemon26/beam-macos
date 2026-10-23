# Changelog

All notable changes to Beam. Versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

## [1.1.0] - 2026-10-23

Every window, one keystroke away.

Upgrading from 1.0.0: grant Accessibility once more; future updates keep it.

### Added

- **Bundles** — group a project's windows and files. ⌥ Tab lists them first; Enter opens a bundle, ⌘ Enter brings
  all its windows forward, ⌘ G adds a window or file. Manage them in **Settings ▸ Bundles**.
- **File search** — `f <text>` or **Search Files** in the launcher finds files by name in chosen folders. Enter shows
  the file in Finder, ⌘ Enter opens it. Off by default (**Settings ▸ File Search**).
- **Search history** — ↑ in an empty search field recalls earlier searches. Clear it in **Settings ▸ Launcher**.
- **Rebindable shortcuts** — change every hotkey, plus optional ones for Search Files and Settings
  (**Settings ▸ Shortcuts**).
- **Show Beam on** — the screen with the mouse, the active window, or the primary screen.
- A switch to hide calculator results.

### Changed

- Updates keep the Accessibility permission.
- Only one Beam runs at a time; opening a newer version replaces the older one.
- Settings reorganised: General, Shortcuts, Launcher, Calculator, File Search, Bundles, About.

## [1.0.0] - 2026-10-21

Every window, one keystroke away.

- **⌃ Tab** — switch between the windows of the current app, across Desktops, including minimized ones.
- **⌥ Tab** — search every window by app name or title.
- **⌥ Space** — fuzzy app launcher that learns what you use most.
- **Calculator** — percentages, units, currencies, time zones and dates, as you type.
- Settings for open at login, menu-bar icon, launcher hotkey and appearance.
- Guided Accessibility setup. macOS 15 or later, Apple silicon and Intel.

[Unreleased]: https://github.com/awaismemon26/beam-macos/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/awaismemon26/beam-macos/releases/tag/v1.1.0
[1.0.0]: https://github.com/awaismemon26/beam-macos/releases/tag/v1.0.0
