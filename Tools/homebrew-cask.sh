#!/bin/bash
# Prints the Homebrew cask for a release, for the tap at github.com/awaismemon26/homebrew-tap (Casks/beam.rb).
# The checksum must be the one of the disk image attached to the GitHub release (it's in the release notes).
#
#   Tools/homebrew-cask.sh 1.1.0 <sha256>  > ../homebrew-tap/Casks/beam.rb
#   Tools/homebrew-cask.sh 1.1.0           (reads dist/Beam-1.1.0.dmg.sha256)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1#v}"
SHA="${2:-$(cut -d' ' -f1 "$ROOT/dist/Beam-$VERSION.dmg.sha256")}"
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "error: '$SHA' is not a SHA-256" >&2; exit 1; }

cat <<CASK
cask "beam" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/awaismemon26/beam-macos/releases/download/v#{version}/Beam-#{version}.dmg"
  name "Beam"
  desc "Native window switcher and launcher"
  homepage "https://github.com/awaismemon26/beam-macos"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

  app "Beam.app"

  uninstall quit: "dev.beam.Beam"

  zap trash: [
    "~/Library/Application Support/Beam",
    "~/Library/Caches/dev.beam.Beam",
    "~/Library/HTTPStorages/dev.beam.Beam",
    "~/Library/Preferences/dev.beam.Beam.plist",
  ]

  caveats <<~EOS
    Beam isn't notarized yet. The first time you open it, macOS says it can't verify it:
    click Done, then open System Settings > Privacy & Security and click Open Anyway.
    Then open Beam again and turn on Accessibility when it asks.
  EOS
end
CASK
