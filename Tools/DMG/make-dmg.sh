#!/bin/bash
# Packages Beam.app as a disk image: the app, an Applications shortcut, and a background that shows
# drag-to-install plus the first-launch steps. Uses dmgbuild (pinned, installed into build/), which writes
# Finder's window layout directly, so it needs no Finder scripting and works headless in CI.
#
#   Tools/DMG/make-dmg.sh <path/to/Beam.app> <out.dmg>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$1" OUT="$2"
VENV="$ROOT/build/dmgbuild-venv"
[ -x "$VENV/bin/dmgbuild" ] || { python3 -m venv "$VENV" && "$VENV/bin/pip" install -q --disable-pip-version-check dmgbuild==1.6.7; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swift "$ROOT/Tools/DMG/DrawBackground.swift" "$WORK"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/background.tiff" >/dev/null 2>&1

rm -f "$OUT"
"$VENV/bin/dmgbuild" -s "$ROOT/Tools/DMG/settings.py" -D app="$APP" -D background="$WORK/background.tiff" Beam "$OUT" \
    >"$WORK/dmgbuild.log" 2>&1 || { cat "$WORK/dmgbuild.log"; exit 1; }
hdiutil verify -quiet "$OUT"
