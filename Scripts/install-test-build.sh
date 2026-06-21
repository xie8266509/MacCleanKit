#!/usr/bin/env bash
set -euo pipefail

APP_SOURCE="${1:-}"
APP_DEST="/Applications/MacCleanKit.app"

if [[ -z "$APP_SOURCE" ]]; then
  if [[ -d "dist/MacCleanKit.app" ]]; then
    APP_SOURCE="dist/MacCleanKit.app"
  elif [[ -d "/Volumes/MacCleanKit/MacCleanKit.app" ]]; then
    APP_SOURCE="/Volumes/MacCleanKit/MacCleanKit.app"
  else
    echo "Usage: Scripts/install-test-build.sh /path/to/MacCleanKit.app" >&2
    echo "Or mount MacCleanKit.dmg first, then run this script from the repository root." >&2
    exit 2
  fi
fi

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "App source was not found: $APP_SOURCE" >&2
  exit 2
fi

echo "Installing test build from: $APP_SOURCE"
SOURCE_PATH="$(cd "$(dirname "$APP_SOURCE")" && pwd)/$(basename "$APP_SOURCE")"
if [[ "$SOURCE_PATH" != "$APP_DEST" ]]; then
  rm -rf "$APP_DEST"
  cp -R "$APP_SOURCE" "$APP_DEST"
fi
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

echo "Installed: $APP_DEST"
echo "Opening MacCleanKit..."
open "$APP_DEST"
