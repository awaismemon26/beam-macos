#!/bin/bash
# Builds the distributable Beam.app and packages it as dist/Beam-<version>.dmg plus a SHA-256 checksum.
# Used by the release workflow. The build is ad-hoc signed; when BEAM_SIGNING_IDENTITY names a keychain
# identity (e.g. "Beam", see Tools/make-signing-cert.sh) the app is re-signed with it afterwards, so every
# release shares one designated requirement and macOS keeps Accessibility across updates.
#
#   Tools/build-release.sh [version] [build-number]
#   BEAM_SIGNING_IDENTITY=Beam [BEAM_SIGNING_KEYCHAIN=/path/to.keychain-db] Tools/build-release.sh 1.1.0
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
IDENTITY="${BEAM_SIGNING_IDENTITY:-}"
if [ -n "$IDENTITY" ]; then
    # Re-sign outside Xcode (it would look the identity up in the keychain search list). Hardened runtime
    # stays off (no --options runtime): library validation refuses the embedded framework otherwise.
    SIGN=(codesign --force --sign "$IDENTITY" --timestamp=none --preserve-metadata=entitlements)
    [ -n "${BEAM_SIGNING_KEYCHAIN:-}" ] && SIGN+=(--keychain "$BEAM_SIGNING_KEYCHAIN")
    for item in "$APP"/Contents/Frameworks/*; do
        [ -e "$item" ] && "${SIGN[@]}" "$item"
    done
    "${SIGN[@]}" "$APP"
    DETAILS="$(codesign -dvv "$APP" 2>&1)"
    grep -q "^Authority=$IDENTITY\$" <<<"$DETAILS" \
        || { echo "error: $APP is not signed by \"$IDENTITY\""; exit 1; }
    echo "Signed with \"$IDENTITY\""
else
    echo "note: no BEAM_SIGNING_IDENTITY; ad-hoc signing (Accessibility will not survive updates)"
fi
codesign --verify --deep --strict "$APP"
# The app must not carry build-machine paths (they name the builder's home folder).
if LC_ALL=C grep -a -q -E "/Users/|/home/runner" "$APP/Contents/MacOS/Beam"; then
    echo "error: build paths found in the Beam binary"; exit 1
fi
mkdir -p dist
DMG="dist/Beam-$VERSION.dmg"
Tools/DMG/make-dmg.sh "$APP" "$DMG"
(cd dist && shasum -a 256 "Beam-$VERSION.dmg" > "Beam-$VERSION.dmg.sha256")
echo "Built $DMG ($(du -h "$DMG" | cut -f1)), version $VERSION ($BUILD)"
cat "dist/Beam-$VERSION.dmg.sha256"
