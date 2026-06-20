#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ZIP="$ROOT_DIR/dist/MacCleanKit.app.zip"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "Set NOTARY_PROFILE to a notarytool keychain profile name." >&2
  exit 2
fi

if [[ ! -f "$APP_ZIP" ]]; then
  echo "Missing $APP_ZIP. Run Scripts/package-app.sh first." >&2
  exit 2
fi

xcrun notarytool submit "$APP_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$ROOT_DIR/dist/MacCleanKit.app"
spctl -a -vv "$ROOT_DIR/dist/MacCleanKit.app"
