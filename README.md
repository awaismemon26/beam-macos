# Beam

A fast, native macOS launcher: Ctrl+Tab same-app window switcher, Option+Tab window search,
and an Option+Space root search with a SoulverCore-powered calculator.

## Build & run

```bash
xcodegen generate
xcodebuild -project Beam.xcodeproj -scheme Beam -configuration Debug -derivedDataPath build BEAM_TEAM_ID=<your team id> -allowProvisioningUpdates build
open build/Build/Products/Debug/Beam.app
```

Without a Team ID, build ad-hoc instead (append `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`).
Ad-hoc builds change identity on every rebuild, so macOS forgets the Accessibility permission each
time and you must re-grant it.

Unit tests for the core logic:

```bash
cd Packages/BeamKit && swift test
```
