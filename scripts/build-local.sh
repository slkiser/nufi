#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate
xcodebuild \
  -project Nufi.xcodeproj \
  -scheme Nufi \
  -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=28W383DD2Q \
  build

APP="$ROOT/build/DerivedData/Build/Products/Release/Nufi.app"
DEST="$ROOT/build/Nufi.app"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
echo "Built $DEST"
