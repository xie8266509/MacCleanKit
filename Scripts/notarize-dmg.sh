#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG="$ROOT_DIR/dist/MacCleanKit.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "Set NOTARY_PROFILE to a notarytool keychain profile name." >&2
  exit 2
fi

if [[ ! -f "$DMG" ]]; then
  echo "Missing $DMG. Run Scripts/package-dmg.sh first." >&2
  exit 2
fi

xcrun notarytool submit "$DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$DMG"
spctl -a -vv -t open --context context:primary-signature "$DMG"
