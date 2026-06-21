#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT_DIR/dist/MacCleanKit.app"
DMG="$ROOT_DIR/dist/MacCleanKit.dmg"
STAGING="$ROOT_DIR/dist/dmg-staging"
README="$STAGING/README-FIRST.txt"
INCLUDE_TEST_README="${INCLUDE_TEST_README:-1}"

if [[ ! -d "$APP" ]]; then
  "$ROOT_DIR/Scripts/package-app.sh"
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

if [[ "$INCLUDE_TEST_README" == "1" ]]; then
  cat > "$README" <<'TEXT'
MacCleanKit Test Build

This build is ad-hoc signed and is not Apple Developer ID notarized.

If macOS says "MacCleanKit is damaged and can't be opened", it is Gatekeeper blocking a non-notarized browser download. It does not necessarily mean the app bundle is corrupted.

For trusted testing only:

1. Drag MacCleanKit.app to Applications.
2. Open Terminal.
3. Run:

   xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
   open /Applications/MacCleanKit.app

If the command needs administrator permission:

   sudo xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
   open /Applications/MacCleanKit.app

Do not use this workaround for public production distribution. Public macOS apps should be Developer ID signed, notarized, and stapled.
TEXT
fi

hdiutil create \
  -volname "MacCleanKit" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGING"
echo "Built $DMG"
