#!/bin/bash
# Builds a universal dist/Breeze-<version>.dmg.
# Usage: scripts/build-dmg.sh 1.2.0 [build-number]
# ADHOC=1 ignores Config/Local.xcconfig and signs ad-hoc (used by CI).
set -euo pipefail

VERSION="${1:?usage: build-dmg.sh <version> [build]}"
BUILD="${2:-1}"
cd "$(dirname "$0")/.."

SIGNING=()
if [[ "${ADHOC:-0}" == "1" ]]; then
  SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
fi

xcodegen generate --quiet
xcodebuild -project Breeze.xcodeproj -scheme Breeze -configuration Release \
  -derivedDataPath build.noindex -destination 'generic/platform=macOS' \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  "${SIGNING[@]}" \
  -quiet build

APP=build.noindex/Build/Products/Release/Breeze.app
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Breeze.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
DMG="dist/Breeze-$VERSION.dmg"
hdiutil create -quiet -volname "Breeze $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
(cd dist && shasum -a 256 "Breeze-$VERSION.dmg" | tee "Breeze-$VERSION.dmg.sha256")
