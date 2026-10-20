# Beam

A fast, native macOS launcher (Swift 6, SwiftUI + AppKit, no web views):

- **Ctrl+Tab**: switch between windows of the app you're in (VS Code, Teams, Chrome…)
- **Option+Tab**: search every window by app name or title
- **Option+Space**: launch apps and calculate (`5 % of 5000`, `100 usd in eur`, `3pm london in tokyo`)

## Build & run

```bash
xcodegen generate
```

Signed with your Apple Development team (keeps the Accessibility permission across rebuilds). Find the
Team ID in Xcode ▸ Settings ▸ Accounts ▸ your team:

```bash
xcodebuild -project Beam.xcodeproj -scheme Beam -configuration Release -derivedDataPath build BEAM_TEAM_ID=<TEAM_ID> -allowProvisioningUpdates build
```

Without a team (ad-hoc). Hardened runtime must be off, or macOS refuses to load SoulverCore. macOS also
forgets the Accessibility permission after every rebuild:

```bash
xcodebuild -project Beam.xcodeproj -scheme Beam -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual ENABLE_HARDENED_RUNTIME=NO build
```

```bash
open build/Build/Products/Release/Beam.app
```

Core-logic tests:

```bash
cd Packages/BeamKit && swift test
```

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
- [ ] Holding Control: Tab moves down (wraps), Shift+Tab moves up, and Enter jumps to that exact window and closes the panel.
- [ ] Ctrl+Tab, then releasing Control, closes the panel and nothing changes. Esc also closes it.
- [ ] In Chrome, the Desktop 2 window says "Desktop 2", and Enter on it switches to Desktop 2 with that window in front.
- [ ] The minimized window says "Minimized", and Enter on it restores it.
- [ ] Quick flip: Ctrl+Tab, Enter, Ctrl+Tab, Enter returns you to the first window.
- [ ] Typing elsewhere, Cmd+Tab and Ctrl+arrows still behave normally.

**Option+Tab: window search**
- [ ] Option+Tab opens a search panel listing every window. It doesn't type a tab or a special character in the app behind it.
- [ ] "chrome" shows all 3 Chrome windows, "vscode" shows both VS Code windows, and "jira" finds a Chrome tab titled Jira.
- [ ] ↑↓ / Tab move, Enter focuses, Esc or clicking elsewhere closes.

**Option+Space: launcher + calculator**
- [ ] "5 % of 5000" shows **250** on top. Enter copies it (`pbpaste` prints `250`) and shows "Copied".
- [ ] "100 usd in eur", "3pm london in tokyo", "65 kg in pounds" and "days until dec 25" all show answers.
- [ ] "saf" puts Safari first, "vsc" finds Visual Studio Code, and Enter launches it.
- [ ] "1password" (if installed) shows the app and no calculator row.
- [ ] "switch" → *Switch Windows* opens window search. "settings" → *Beam Settings* opens Settings.
- [ ] Option+Space again (or Esc) hides the panel.

**Settings**
- [ ] Rebind "Open Beam" to Ctrl+Space. Option+Space no longer opens Beam, Ctrl+Space does, and the change survives a relaunch.
- [ ] The launch-at-login toggle matches System Settings ▸ General ▸ Login Items.
- [ ] Calculator ▸ Refresh now updates the "Updated…" time.

**Robustness**
- [ ] With a hung app (beachball), Ctrl+Tab and Option+Tab still open instantly. The hung app's windows may be missing.
- [ ] Debug builds: menu-bar ▸ *Dump windows* logs every window with badges, viewable with
  `log stream --predicate 'subsystem == "dev.beam.Beam"'`.

## Performance

Signposts (`switcher.open`, `windowSearch.open`, `root.open`, `root.query`) appear in Instruments ▸
*Points of Interest*. Targets: hotkey → panel < 16 ms, keystroke → results < 16 ms. Measured idle (Release):
0.0% CPU, 31 MB footprint.
