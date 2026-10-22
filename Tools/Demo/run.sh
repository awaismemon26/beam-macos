#!/bin/bash
# Regenerates assets/demo.gif from Beam's real SwiftUI views (offscreen, sample data only).
#   Tools/Demo/run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

strip() { sed -e 's/^import BeamCore$//' -e 's/^import BeamCalc$//' "$1"; }
# Everything above the first marker line (the controller class) is the model code the views need.
models() { strip "$1" | awk -v marker="$2" 'index($0, marker) == 1 {exit} {print}'; }

for f in "$ROOT"/Packages/BeamKit/Sources/BeamCore/*.swift; do strip "$f" > "$WORK/core_$(basename "$f")"; done
for f in RootSearchView WindowSearchView SwitcherView SearchField ResultRow WindowRow BundleRow BundlePicker FileRow; do strip "$ROOT/App/UI/$f.swift" > "$WORK/$f.swift"; done
models "$ROOT/App/UI/RootSearchController.swift" "/// Option+Space" > "$WORK/RootModels.swift"
models "$ROOT/App/UI/SwitcherController.swift" "/// The Ctrl+Tab panel" > "$WORK/SwitcherModels.swift"
models "$ROOT/App/UI/WindowSearchController.swift" "/// Option+Tab" \
    | sed 's/NSRunningApplication(processIdentifier: pid)?.icon/demoIcon(pid)/' > "$WORK/WindowSearchModels.swift"
# The live blur can't be captured offscreen; MakeDemo draws frosted glass behind the panel instead.
strip "$ROOT/App/UI/Theme.swift" | sed 's/\.background(VisualEffectBackground())/.background(Color.clear)/' > "$WORK/Theme.swift"
cp "$ROOT/Tools/Demo/MakeDemo.swift" "$WORK/main.swift"

# Swift 5 mode: the one-shot driver keeps its state in top-level globals.
(cd "$WORK" && xcrun swiftc -swift-version 5 -O -o demo ./*.swift)
mkdir -p "$ROOT/assets"
"$WORK/demo" "$ROOT/assets/demo.gif" "$ROOT/App/Assets.xcassets/AppIcon.appiconset/icon_512.png"
ls -lh "$ROOT/assets/demo.gif" | awk '{print $5, $9}'
