# Beam

A fast, native macOS launcher (Swift 6, SwiftUI + AppKit, no web views):

- **Ctrl+Tab**: switch between windows of the app you're in (VS Code, Teams, Chrome…)
- **Option+Tab**: search every window by app name or title
- **Option+Space**: launch apps and calculate (`5 % of 5000`, `100 usd in eur`, `3pm london in tokyo`)

## Build & run

Requirements: macOS 27, Xcode 27, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

1. Configure signing (optional but recommended):

   ```bash
   cp .env.example .env
   ```

   Put your Apple Development team ID in `.env` as `BEAM_TEAM_ID`. Find it in Xcode ▸ Settings ▸ Accounts, or
   in the OU field of your "Apple Development" certificate. With a team, macOS keeps Beam's Accessibility
   permission across rebuilds. Without one, Beam is built unsigned (ad-hoc) and asks again after every rebuild.
   If signing fails with "0 valid identities", install Apple's
   [WWDR G3 intermediate certificate](https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer).

2. Build, install into `/Applications` and launch:

   ```bash
   Tools/install.sh
   ```

   Or generate the Xcode project and work in Xcode:

   ```bash
   Tools/generate.sh
   ```

## Tests

| What | Command | Needs |
|---|---|---|
| Core logic: hotkeys, switcher state, fuzzy matching, ranking, calculator gate, keystroke performance (BeamKit, 107 tests) | `cd Packages/BeamKit && swift test` | — |
| Keystroke performance with optimisations on (shipping numbers) | `cd Packages/BeamKit && swift test -c release -Xswiftc -enable-testing --filter PerformanceTests` | — |
| Window-search rendering: draws the real Option+Tab view offscreen and reads the rows back | `Tools/RenderCheck/run.sh` | — |
| End to end against the installed Beam: launcher, calculator, "settings" + Enter, window search, Ctrl+Tab, idle CPU/memory | `swift Tools/LiveTests/LiveTests.swift` | Beam running; Accessibility for your terminal; US keyboard layout |

The live tests type only after Beam reports its own search field as focused, and end every check with Esc.
Pass test names to run a subset, e.g. `swift Tools/LiveTests/LiveTests.swift settings switcher`.

## First run

1. Beam shows a welcome window asking for **Accessibility** access. Click *Open System Settings* and turn
   on **Beam** under Privacy & Security ▸ Accessibility. The window closes by itself once access is granted.
2. Turn off Raycast's own hotkey so Option+Space reaches Beam: Raycast ▸ Settings ▸ General ▸ Raycast
   Hotkey ▸ clear it, or quit Raycast.
3. Beam adds itself to Login Items on first launch. Turn this off in Beam Settings (⌘, in any Beam panel, or the
   menu-bar icon ▸ Settings…).

## Manual verification checklist

Setup: open **3 Chrome windows** (minimize one with ⌘M; move one to **Desktop 2** in Mission Control) and
**2 VS Code windows** on Desktop 1.

**Menu bar & permission**
- [ ] A ⌘-square icon is in the menu bar, and there's no Beam icon in the Dock.
- [ ] The welcome window closes by itself after you grant Accessibility.

**Ctrl+Tab: windows of the current app**
- [ ] In VS Code, Ctrl+Tab shows both VS Code windows, with the *second* one highlighted. VS Code does **not** switch editor tabs.
- [ ] Holding Control: Tab moves down (wraps), Shift+Tab moves up. Releasing Control (or Enter) jumps to the highlighted window.
- [ ] A single quick Ctrl+Tab flips to the previous window. Ctrl+Tab, then Esc, closes the panel and nothing changes.
- [ ] In Chrome, the Desktop 2 window says "Desktop 2", and Enter on it switches to Desktop 2 with that window in front.
- [ ] The minimized window says "Minimized", and Enter on it restores it.
- [ ] Quick flip: Ctrl+Tab twice (releasing in between) returns you to the first window.
- [ ] Typing elsewhere, Cmd+Tab and Ctrl+arrows still behave normally.

**Option+Tab: window search**
- [ ] Option+Tab opens a search panel listing every window. It doesn't type a tab or a special character in the app behind it.
- [ ] "chrome" shows exactly the 3 Chrome windows (the rows, not just the count), "vscode" shows both VS Code windows, and "jira" finds a Chrome tab titled Jira.
- [ ] ↑↓ / Tab move, Enter focuses, Esc or clicking elsewhere closes.

**Option+Space: launcher + calculator**
- [ ] "5 % of 5000" shows **250** on top. Enter copies it (`pbpaste` prints `250`) and shows "Copied".
- [ ] "100 usd in eur", "3pm london in tokyo", "65 kg in pounds" and "days until dec 25" all show answers.
- [ ] "saf" puts Safari first, "vsc" finds Visual Studio Code, and Enter launches it.
- [ ] "1password" (if installed) shows the app and no calculator row.
- [ ] "switch" → *Switch Windows* opens window search. "settings" → *Beam Settings* opens Settings.
- [ ] Option+Space again (or Esc) hides the panel.

**Settings**
- [ ] Settings has a General and an About pane (sidebar), in the style of Raycast's settings.
- [ ] Rebind "Beam Hotkey" to Ctrl+Space. Option+Space no longer opens Beam, Ctrl+Space does, and the change survives a relaunch. ↺ resets it to ⌥ Space.
- [ ] "Open at Login" matches System Settings ▸ General ▸ Login Items, and Beam starts after logging in.
- [ ] "Show in Menu Bar" off hides the icon; opening Beam again (Spotlight/Finder) or ⌘, in Beam opens Settings.
- [ ] "Follow System Appearance" off shows Light/Dark; panels and Settings switch immediately.
- [ ] About ▸ Currency Rates ▸ Refresh updates the "Updated…" time.

**Robustness**
- [ ] With a hung app (beachball), Ctrl+Tab and Option+Tab still open instantly. The hung app's windows may be missing.
- [ ] Debug builds: menu-bar ▸ *Dump windows* logs every window with badges, viewable with
  `log stream --predicate 'subsystem == "dev.beam.Beam"'`.

## Performance

Measured on an Apple-silicon Mac (release build, macOS 27):

| | |
|---|---|
| Hotkey → panel with a focused search field | ~1 ms (first open after launch ~25 ms) |
| Ctrl+Tab → switcher visible | ~10 ms |
| "settings" + Enter → Settings in front with keyboard focus | ~80 ms |
| Worst keystroke, 600 apps / 300 windows | 1.1 ms / 2.2 ms |
| Idle | ~0% CPU, ~46 MB memory footprint |

Signposts (`switcher.open`, `windowSearch.open`, `root.open`, `root.query`) appear in Instruments ▸ Points of Interest.
