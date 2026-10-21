#!/bin/bash
# Prints the GitHub release notes for a version: its CHANGELOG section, install steps and the checksum.
#   Tools/release-notes.sh 1.0.0
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1#v}"
SECTION="$(awk -v v="## [$VERSION]" 'index($0, v) == 1 {on=1; next} on && /^## \[/ {exit} on && !/^\[[^]]*\]: / {print}' "$ROOT/CHANGELOG.md")"
[ -n "$SECTION" ] || { echo "error: no '## [$VERSION]' section in CHANGELOG.md" >&2; exit 1; }
CHECKSUM_FILE="$ROOT/dist/Beam-$VERSION.zip.sha256"

cat <<NOTES
$SECTION

### Install

1. Download **Beam-$VERSION.zip** below, unzip it and move **Beam.app** to **Applications**.
2. Open Beam. It isn't notarized yet, so the first time click **Open Anyway** in **System Settings ▸ Privacy &
   Security** (or run \`xattr -dr com.apple.quarantine /Applications/Beam.app\`).
3. Turn on **Accessibility** for Beam when asked.

Requires macOS 15 or later (Apple silicon or Intel).
NOTES
if [ -f "$CHECKSUM_FILE" ]; then
    printf '\n**SHA-256:** `%s`\n' "$(cut -d' ' -f1 "$CHECKSUM_FILE")"
fi
