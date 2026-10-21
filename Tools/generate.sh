#!/bin/bash
# Generates Beam.xcodeproj with the settings from .env. Run after cloning, then open the project in Xcode.
set -euo pipefail
. "$(dirname "$0")/env.sh"
cd "$ROOT"
xcodegen generate
[ -n "$BEAM_TEAM_ID" ] || echo "note: BEAM_TEAM_ID is empty; set it in .env, or pick a team in Xcode ▸ Signing & Capabilities."
