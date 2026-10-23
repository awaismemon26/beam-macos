#!/bin/bash
# Prints the GitHub release notes for a version: its CHANGELOG section, install steps and the checksum.
#   Tools/release-notes.sh 1.0.0
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1#v}"
SECTION="$(awk -v v="## [$VERSION]" 'index($0, v) == 1 {on=1; next} on && /^## \[/ {exit} on && !/^\[[^]]*\]: / {print}' "$ROOT/CHANGELOG.md")"
[ -n "$SECTION" ] || { echo "error: no '## [$VERSION]' section in CHANGELOG.md" >&2; exit 1; }
CHECKSUM_FILE="$ROOT/dist/Beam-$VERSION.dmg.sha256"

cat <<NOTES
$SECTION

### Install

1. Download **Beam-$VERSION.dmg** below, open it and drag **Beam** into **Applications**.
2. Open Beam. It isn't notarized yet, so macOS says it can't verify it: click **Done** (not Move to Trash), then open
   **System Settings ▸ Privacy & Security**, scroll down and click **Open Anyway**.
3. Open Beam again and turn on **Accessibility** when it asks.

Or with Homebrew: \`brew install --cask awaismemon26/tap/beam\` (step 2 still applies).

Requires macOS 15 or later (Apple silicon or Intel).
NOTES
if [ -f "$CHECKSUM_FILE" ]; then
    printf '\n**SHA-256:** `%s`\n' "$(cut -d' ' -f1 "$CHECKSUM_FILE")"
fi
