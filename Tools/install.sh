#!/bin/bash
# Builds a signed Release of Beam, installs it as /Applications/Beam.app and relaunches it.
# Build-folder copies are dropped from Launch Services so System Settings, Spotlight and Login Items
# all resolve Beam to the installed copy (with its icon).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
cd "$ROOT"
xcodegen generate >/dev/null
xcodebuild -project Beam.xcodeproj -scheme Beam -configuration Release -derivedDataPath build \
    -allowProvisioningUpdates build >/tmp/beam-install-build.log 2>&1 \
    || { grep -E "error:" /tmp/beam-install-build.log | head; exit 1; }
osascript -e 'tell application id "dev.beam.Beam" to quit' >/dev/null 2>&1 || true
pkill -x Beam 2>/dev/null || true
sleep 1
rm -rf /Applications/Beam.app
ditto build/Build/Products/Release/Beam.app /Applications/Beam.app
for copy in build/Build/Products/*/Beam.app; do "$LSR" -u "$ROOT/$copy" 2>/dev/null || true; done
"$LSR" -f /Applications/Beam.app
open /Applications/Beam.app
echo "Installed /Applications/Beam.app"
