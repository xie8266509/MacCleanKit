#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT_DIR/dist/MacCleanKit.app"
DMG="$ROOT_DIR/dist/MacCleanKit.dmg"
STAGING="$ROOT_DIR/dist/dmg-staging"

if [[ ! -d "$APP" ]]; then
  "$ROOT_DIR/Scripts/package-app.sh"
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "MacCleanKit" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGING"
echo "Built $DMG"
