<div align="center">

<img src="assets/logo.png" width="128" height="128" alt="Beam logo">

# Beam

*Every window, one keystroke away.*

**Window switcher + productivity tool for macOS.**<br>
Jump to any window, launch apps and calculate — instantly, from the keyboard.

[![Latest release](https://img.shields.io/github/v/release/awaismemon26/beam-macos?label=release&color=7b5cff)](https://github.com/awaismemon26/beam-macos/releases/latest)
[![CI](https://github.com/awaismemon26/beam-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/awaismemon26/beam-macos/actions/workflows/ci.yml)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)](#install)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[**Download**](https://github.com/awaismemon26/beam-macos/releases/latest) ·
[Features](#features) ·
[Install](#install) ·
[Shortcuts](#shortcuts) ·
[Build from source](#build-from-source)

<br>

<img src="assets/demo.gif" width="800" alt="Beam: launcher with calculator, window search and the Ctrl+Tab window switcher">

</div>

## Features

- **⌃ Tab — switch windows of the current app.** VS Code, Chrome, Teams, Xcode: hold Control, tap Tab to
  move, release to jump. Works across Desktops and brings back minimized windows. Esc cancels.
- **⌥ Tab — search every window.** Type an app name (`chrome`, `vscode`, `teams`) or part of a window title
  (`jira`, `invoice`) and press Enter to go straight to that window — on any Desktop, even if minimized.
- **⌥ Space — launcher.** Fuzzy app search that learns what you open most, plus Beam's own commands
  (“settings”, “switch windows”).
- **Built-in calculator.** `5 % of 5000`, `100 usd in eur`, `65 kg in lb`, `3pm london in tokyo`,
  `days until dec 25` — the answer appears as you type; Enter copies it.
- **Native and light.** Swift, SwiftUI and AppKit — no web views, no Electron. Panels open instantly, and Beam
  idles at ~0% CPU and ~45 MB of memory.
- **Yours to tune.** Rebind the launcher hotkey, open at login, hide the menu-bar icon, follow the system
  appearance or pick light/dark.
- **No account needed.** Install Beam and start using it. There is no sign-in and no telemetry.

## Install

1. Download **`Beam-<version>.zip`** from the [latest release](https://github.com/awaismemon26/beam-macos/releases/latest)
   and unzip it.
2. Drag **Beam.app** into **Applications**.
3. Open Beam. It isn't notarized by Apple yet, so the first time macOS says it can't verify the app:
   open **System Settings ▸ Privacy & Security** and click **Open Anyway** (or run
   `xattr -dr com.apple.quarantine /Applications/Beam.app` once).
4. Beam asks for **Accessibility** access — turn it on in the window that appears. The Beam icon then shows up
   in the menu bar.

> **Using Raycast or Alfred?** Beam's launcher uses ⌥ Space by default. Change it in **Settings ▸ Beam Hotkey**,
> or free ⌥ Space in the other app.

**Requirements:** macOS 15 Sequoia or later, Apple silicon or Intel.

## Shortcuts

| Shortcut | What it does |
|---|---|
| <kbd>⌃</kbd> <kbd>Tab</kbd> | Switch windows of the current app. Keep holding <kbd>⌃</kbd>: <kbd>Tab</kbd> / <kbd>⇧</kbd> <kbd>Tab</kbd> move, releasing <kbd>⌃</kbd> jumps, <kbd>Esc</kbd> cancels. |
| <kbd>⌥</kbd> <kbd>Tab</kbd> | Search all windows. <kbd>↑</kbd> <kbd>↓</kbd> select, <kbd>⏎</kbd> go, <kbd>Esc</kbd> close. |
| <kbd>⌥</kbd> <kbd>Space</kbd> | Launcher and calculator (rebindable). <kbd>⏎</kbd> opens the app or copies the answer. |
| <kbd>⌘</kbd> <kbd>,</kbd> | Beam Settings (from the launcher). Opening Beam again also shows Settings. |

## Permissions & privacy

- **Accessibility** is required to list windows and bring the one you pick to the front. Like other window
  switchers, Beam also uses a few macOS window-server functions to reach windows on other Desktops.
- **No telemetry, no accounts.** Beam's only network request fetches currency exchange rates from the
  European Central Bank for the calculator, every few hours. Everything else stays on your Mac.

## Build from source

Requirements: Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/awaismemon26/beam-macos.git
cd beam-macos
cp .env.example .env     # optional: set BEAM_TEAM_ID to your Apple Development team
Tools/install.sh         # builds, installs into /Applications and launches Beam
```

With a team ID, macOS keeps Beam's Accessibility permission across rebuilds; without one, Beam is built
unsigned and asks again after each rebuild. To work in Xcode instead, run `Tools/generate.sh` and open
`Beam.xcodeproj`. `Tools/build-release.sh` produces the same zip as the release pipeline.

### Tests

| Suite | Command |
|---|---|
| Core logic and keystroke performance (107 tests) | `cd Packages/BeamKit && swift test` |
| Window-search rendering check | `Tools/RenderCheck/run.sh` |
| End to end against the installed app | `swift Tools/LiveTests/LiveTests.swift` |

The end-to-end tests drive the real hotkeys, so they need Beam running, Accessibility access for your terminal
and a US keyboard layout. They type only after Beam's own search field has focus.

### Project layout

```
App/                 macOS app: event tap, window enumeration and focusing, panels, settings
Packages/BeamKit/    pure, unit-tested logic (BeamCore) and the calculator wrapper (BeamCalc)
Tools/               install, release build, demo GIF, rendering check and end-to-end tests
```

## Contributing

Bug reports, ideas and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Release history is in [CHANGELOG.md](CHANGELOG.md).

## Acknowledgements

- Reaching windows on other Desktops follows the technique documented by
  [AltTab](https://github.com/lwouis/alt-tab-macos).

## License

Beam is released under the [MIT License](LICENSE).
