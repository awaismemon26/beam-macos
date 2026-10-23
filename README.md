<div align="center">

<img src="assets/logo.png" width="128" height="128" alt="Beam logo">

# Beam

*Every window, one keystroke away.*

**Window switcher + productivity tool for macOS.**<br>
Jump to any window, launch apps, find files and calculate — instantly, from the keyboard.

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
- **Bundles — one per project.** Group the windows and files of a project or task (“flagsmith”: three VS Code
  windows, an Excel sheet, a PDF). Bundles are listed first in ⌥ Tab with a grey “4 windows”; ⌘ Enter brings all
  of a bundle's windows forward at once, across apps. Highlight a window and press ⌘ G to add it; it rejoins
  after a restart by itself. Edit them in Settings ▸ Bundles.
- **⌥ Space — launcher.** Fuzzy app search that learns what you open most, plus Beam's own commands
  (“settings”, “switch windows”, “search files”).
- **File search.** Type `f awais cv` in the launcher, or run **Search Files**, to find files by name in the
  folders you choose (Desktop, Documents, Downloads, Pictures, iCloud Drive by default). Enter reveals the file
  in Finder, ⌘ Enter opens it. Off until you turn it on in Settings ▸ File Search.
- **Search history.** Press ↑ in an empty launcher or window-search field to bring back what you searched
  before. Clear it any time in Settings ▸ Launcher.
- **Built-in calculator.** `5 % of 5000`, `100 usd in eur`, `65 kg in lb`, `3pm london in tokyo`,
  `days until dec 25` — the answer appears as you type; Enter copies it. Can be switched off.
- **Every shortcut is yours.** Rebind the launcher, window search and window switcher hotkeys, or add
  optional ones for Search Files and Settings, in Settings ▸ Shortcuts.
- **Native and light.** Swift, SwiftUI and AppKit — no web views, no Electron. Panels open instantly, and Beam
  idles at ~0% CPU and ~45 MB of memory.
- **Yours to tune.** Open at login, hide the menu-bar icon, choose which screen Beam appears on, follow the
  system appearance or pick light/dark.
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

Updates are signed with the same certificate every time, so Beam keeps its Accessibility access when you
update. (Coming from 1.0.0, grant it once more.)

> **Using Raycast or Alfred?** Beam's launcher uses ⌥ Space by default. Change it in **Settings ▸ Shortcuts**,
> or free ⌥ Space in the other app.

**Requirements:** macOS 15 Sequoia or later, Apple silicon or Intel.

## Shortcuts

All global shortcuts can be changed in **Settings ▸ Shortcuts**; the table shows the defaults.

| Shortcut | What it does |
|---|---|
| <kbd>⌃</kbd> <kbd>Tab</kbd> | Switch windows of the current app. Keep holding <kbd>⌃</kbd>: <kbd>Tab</kbd> / <kbd>⇧</kbd> <kbd>Tab</kbd> move, releasing <kbd>⌃</kbd> jumps, <kbd>Esc</kbd> cancels. |
| <kbd>⌥</kbd> <kbd>Tab</kbd> | Search bundles and all windows. <kbd>↑</kbd> <kbd>↓</kbd> select, <kbd>⏎</kbd> go (or open a bundle), <kbd>⌘</kbd> <kbd>⏎</kbd> bring a bundle's windows forward, <kbd>⌘</kbd> <kbd>G</kbd> add the window to a bundle, <kbd>Esc</kbd> close. |
| <kbd>⌥</kbd> <kbd>Space</kbd> | Launcher, calculator and file search. <kbd>⏎</kbd> opens the app, copies the answer or reveals the file in Finder; <kbd>⌘</kbd> <kbd>⏎</kbd> opens a file; <kbd>↑</kbd> in an empty field recalls earlier searches. |
| none | Optional hotkeys for **Search Files** and **Beam Settings** — set them in Settings ▸ Shortcuts. |
| <kbd>⌘</kbd> <kbd>,</kbd> | Beam Settings (from the launcher). Opening Beam again also shows Settings. |

In file search, <kbd>⌘</kbd> <kbd>G</kbd> adds the file to a bundle and <kbd>⇧</kbd> <kbd>⌘</kbd> <kbd>G</kbd> saves the
search to one. Inside a bundle, <kbd>⌘</kbd> <kbd>⌫</kbd> removes the highlighted window or file.

## Permissions & privacy

- **Accessibility** is required to list windows and bring the one you pick to the front. Like other window
  switchers, Beam also uses a few macOS window-server functions to reach windows on other Desktops.
- **File search is off until you turn it on.** Beam then asks the system's Spotlight index for file *names* in
  your chosen folders, and macOS may ask once for access to Desktop, Documents and Downloads. File names, search
  text and bundles never leave your Mac.
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
unsigned and asks again after each rebuild. Release builds are signed with a self-made certificate
(`Tools/make-signing-cert.sh`). To work in Xcode instead, run `Tools/generate.sh` and open
`Beam.xcodeproj`. `Tools/build-release.sh` produces the same zip as the release pipeline.

### Tests

| Suite | Command |
|---|---|
| Core logic and keystroke performance (223 tests) | `cd Packages/BeamKit && swift test` |
| Window-search rendering check | `Tools/RenderCheck/run.sh` |
| End to end against the installed app | `swift Tools/LiveTests/LiveTests.swift` |

The end-to-end tests drive the real hotkeys, so they need Beam running and Accessibility access for your
terminal. They work with any keyboard layout and type only after Beam's own search field has focus.

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
