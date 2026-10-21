#!/bin/bash
# Builds a signed Release of Beam, installs it as /Applications/Beam.app and relaunches it.
# Build-folder copies are dropped from Launch Services so System Settings, Spotlight and Login Items
# all resolve Beam to the installed copy (with its icon).
set -euo pipefail
. "$(dirname "$0")/env.sh"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
cd "$ROOT"
xcodegen generate >/dev/null
if [ -n "$BEAM_TEAM_ID" ]; then
    SIGN=(BEAM_TEAM_ID="$BEAM_TEAM_ID" -allowProvisioningUpdates)
else
    echo "note: no BEAM_TEAM_ID in .env; building unsigned. macOS will ask for Accessibility again after each rebuild."
    # Hardened runtime must be off for ad-hoc builds, or macOS refuses to load SoulverCore.
    SIGN=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual ENABLE_HARDENED_RUNTIME=NO)
fi
LOG="$(mktemp)"
xcodebuild -project Beam.xcodeproj -scheme Beam -configuration Release -derivedDataPath build \
    "${SIGN[@]}" build >"$LOG" 2>&1 \
    || { grep -E "error:" "$LOG" | head; echo "full log: $LOG"; exit 1; }
osascript -e 'tell application id "dev.beam.Beam" to quit' >/dev/null 2>&1 || true
pkill -x Beam 2>/dev/null || true
sleep 1
rm -rf /Applications/Beam.app
ditto build/Build/Products/Release/Beam.app /Applications/Beam.app
for copy in build/Build/Products/*/Beam.app build/*/Build/Products/*/Beam.app; do "$LSR" -u "$ROOT/$copy" 2>/dev/null || true; done
"$LSR" -f /Applications/Beam.app
open /Applications/Beam.app
echo "Installed /Applications/Beam.app"
