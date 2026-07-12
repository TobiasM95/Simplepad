#!/bin/bash
set -euo pipefail

VERSION="${1:-$(tr -d '[:space:]' < version.txt)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"

rm -rf "$DERIVED_DATA" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT/Simplepad.xcodeproj" \
  -scheme Simplepad \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" \
  build

APP="$DERIVED_DATA/Build/Products/Release/Simplepad.app"
ZIP="$DIST_DIR/Simplepad-$VERSION-macOS-universal.zip"

test -d "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256"
)

echo "Created $ZIP"

