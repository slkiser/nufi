#!/bin/zsh
# Builds a Developer ID signed, notarized, stapled DMG and the matching
# Homebrew cask file. Needs, once, on this Mac:
#   - a "Developer ID Application" certificate in the login keychain
#   - xcrun notarytool store-credentials nufi-notary --apple-id <id> --team-id 28W383DD2Q
# Usage: scripts/release.sh 0.1.0-alpha.1
set -euo pipefail

VERSION="${1:?usage: release.sh <version, e.g. 0.1.0-alpha.1>}"
TEAM="28W383DD2Q"
PROFILE="${NOTARY_PROFILE:-nufi-notary}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*'"$TEAM"'[^"]*\)".*/\1/p' | head -1)"

if [[ -z "$IDENTITY" ]]; then
  echo "No Developer ID Application certificate for team $TEAM in the keychain." >&2
  echo "Create one in Xcode > Settings > Accounts > Manage Certificates, then rerun." >&2
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "Notary profile '$PROFILE' is missing. Run:" >&2
  echo "  xcrun notarytool store-credentials $PROFILE --apple-id <apple id> --team-id $TEAM" >&2
  exit 1
fi

cd "$ROOT"
rm -rf "$OUT" "build/DerivedData/Build/Products"
mkdir -p "$OUT"

xcodegen generate
xcodebuild \
  -project Nufi.xcodeproj -scheme Nufi -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build | tail -3

APP="$ROOT/build/DerivedData/Build/Products/Release/Nufi.app"
codesign --verify --deep --strict --verbose=2 "$APP"

# Notarize the app, staple it, then wrap it in a DMG and notarize that too so
# Gatekeeper is satisfied whether the user opens the DMG or the app.
ditto -c -k --keepParent "$APP" "$OUT/Nufi.zip"
xcrun notarytool submit "$OUT/Nufi.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"

STAGE="$OUT/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/Nufi-$VERSION.dmg"
hdiutil create -volname "Nufi" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"

SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" \
  "$ROOT/scripts/homebrew/nufi.rb.template" > "$OUT/nufi.rb"

cat <<MSG

Release artifacts in $OUT:
  $(basename "$DMG")   sha256 $SHA
  nufi.rb              copy to slkiser/homebrew-tap/Casks/nufi.rb

Next:
  gh release create "v$VERSION" "$DMG" --prerelease --title "Nufi $VERSION" --notes-file <notes>
MSG
