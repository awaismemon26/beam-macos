#!/bin/bash
# Renders the real Option+Tab window-search view with 22 sample windows, types "chrome", and checks
# the rows actually drawn (via Vision text recognition): all 3 Chrome windows, nothing else.
# Needs no Accessibility permission. Usage: Tools/RenderCheck/run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

strip() { sed 's/^import BeamCore$//' "$1"; }
for f in "$ROOT"/Packages/BeamKit/Sources/BeamCore/*.swift; do strip "$f" > "$WORK/core_$(basename "$f")"; done
for f in WindowSearchView WindowRow BundleRow BundlePicker FileRow Theme SearchField ResultRow; do strip "$ROOT/App/UI/$f.swift" > "$WORK/$f.swift"; done
# Only the model part of the controller file (the controller needs the whole app).
strip "$ROOT/App/UI/WindowSearchController.swift" | awk '/^\/\/\/ Option\+Tab/{exit} {print}' > "$WORK/WindowSearchModel.swift"
cp "$ROOT/Tools/RenderCheck/WindowSearchRender.swift" "$WORK/main.swift"

(cd "$WORK" && xcrun swiftc -swift-version 6 -o render ./*.swift)
"$WORK/render" "$WORK/panel.png" & PID=$!
for _ in $(seq 1 100); do kill -0 $PID 2>/dev/null || break; sleep 0.2; done
kill $PID 2>/dev/null && { echo "FAIL: render timed out (view stuck in an update loop?)"; exit 1; }
swift "$ROOT/Tools/RenderCheck/ReadRows.swift" "$WORK/panel.png" | tee "$WORK/result.txt"
grep -q '^PASS$' "$WORK/result.txt"
