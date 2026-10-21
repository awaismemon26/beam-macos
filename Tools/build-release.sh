#!/bin/bash
# Builds the distributable Beam.app (ad-hoc signed, so it carries no personal signing identity) and
# packages it as dist/Beam-<version>.zip plus a SHA-256 checksum. Used by the release workflow.
#
#   Tools/build-release.sh [version] [build-number]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:-$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml)}"
BUILD="${2:-1}"
VERSION="${VERSION#v}"

xcodegen generate >/dev/null
LOG="$(mktemp)"
xcodebuild -project Beam.xcodeproj -scheme Beam -configuration Release -derivedDataPath build/release \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    BEAM_TEAM_ID= CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual ENABLE_HARDENED_RUNTIME=NO \
    DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES STRIP_STYLE=non-global \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    OTHER_SWIFT_FLAGS="-file-prefix-map \"$ROOT=.\" -debug-prefix-map \"$ROOT=.\"" \
    build >"$LOG" 2>&1 || { grep -E "error:" "$LOG" | head -20; echo "full log: $LOG"; exit 1; }

APP=build/release/Build/Products/Release/Beam.app
codesign --verify --deep --strict "$APP"
# The app must not carry build-machine paths (they name the builder's home folder).
if LC_ALL=C grep -a -q -E "/Users/|/home/runner" "$APP/Contents/MacOS/Beam"; then
    echo "error: build paths found in the Beam binary"; exit 1
fi
mkdir -p dist
ZIP="dist/Beam-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "Beam-$VERSION.zip" > "Beam-$VERSION.zip.sha256")
echo "Built $ZIP ($(du -h "$ZIP" | cut -f1)), version $VERSION ($BUILD)"
cat "dist/Beam-$VERSION.zip.sha256"
