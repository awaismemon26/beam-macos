# Contributing to Beam

Thanks for helping make Beam better! Bug reports, feature ideas and pull requests are all welcome.

## Reporting bugs and ideas

Open an [issue](https://github.com/awaismemon26/beam/issues/new/choose) using the bug or feature template.
For bugs, include your macOS version, Beam version (Settings ▸ About) and the steps to reproduce.

## Development setup

You need macOS 15+, Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cp .env.example .env    # optional: BEAM_TEAM_ID keeps Accessibility across rebuilds
Tools/generate.sh       # creates Beam.xcodeproj (git-ignored) for Xcode
Tools/install.sh        # or: build, install into /Applications and launch
```

`Beam.xcodeproj` is generated from `project.yml`; edit `project.yml`, not the project file.

## Code layout

- `Packages/BeamKit/Sources/BeamCore` — pure logic with no UI: hotkey classification, the switcher state
  machine, fuzzy matching, ranking, the calculator gate. Anything testable without a window belongs here.
- `Packages/BeamKit/Sources/BeamCalc` — the SoulverCore wrapper.
- `App/System` — event tap, Accessibility, window enumeration and focusing, settings storage.
- `App/UI` — panels and SwiftUI views.

## Before opening a pull request

1. Add or update tests in `Packages/BeamKit/Tests` for logic changes.
2. Run the checks:

   ```bash
   (cd Packages/BeamKit && swift test)
   Tools/RenderCheck/run.sh
   swift Tools/LiveTests/LiveTests.swift   # needs Beam installed and Accessibility for your terminal
   ```

3. Keep the build free of warnings (Swift 6 strict concurrency is on).
4. If the UI changed, regenerate the demo with `Tools/Demo/run.sh`.
5. Add a line to the `[Unreleased]` section of [CHANGELOG.md](CHANGELOG.md).

## Releasing (maintainers)

1. Move the `[Unreleased]` notes in `CHANGELOG.md` under a new version heading.
2. Tag and push: `git tag v1.1.0 && git push origin v1.1.0`.
3. The **Release** workflow tests, builds a universal `Beam-<version>.zip` with a SHA-256 checksum and creates a
   **draft** GitHub release with the changelog notes. Review it and click **Publish**.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
