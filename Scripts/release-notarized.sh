#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-0.1.3}"
BUILD="${BUILD:-4}"
BUNDLE_ID="${BUNDLE_ID:-com.local.maccleankit}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DOWNLOAD_URL="${DOWNLOAD_URL:-}"

if [[ -z "$CODESIGN_IDENTITY" || "$CODESIGN_IDENTITY" == "-" ]]; then
  echo "Set CODESIGN_IDENTITY to a Developer ID Application certificate name." >&2
  exit 2
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "Set NOTARY_PROFILE to a notarytool keychain profile name." >&2
  exit 2
fi

security find-identity -v -p codesigning | grep -F "$CODESIGN_IDENTITY" >/dev/null || {
  echo "Developer ID identity was not found in the keychain: $CODESIGN_IDENTITY" >&2
  exit 2
}

export VERSION BUILD BUNDLE_ID CODESIGN_IDENTITY NOTARY_PROFILE
Scripts/package-app.sh
Scripts/notarize-app.sh
Scripts/package-dmg.sh
Scripts/notarize-dmg.sh

if [[ -n "$DOWNLOAD_URL" ]]; then
  export DOWNLOAD_URL
fi
Scripts/make-appcast-template.sh

codesign --verify --deep --strict --verbose=2 dist/MacCleanKit.app
spctl -a -vv -t execute dist/MacCleanKit.app
spctl -a -vv -t open --context context:primary-signature dist/MacCleanKit.dmg

echo "Notarized release artifacts are ready:"
echo "  dist/MacCleanKit.app.zip"
echo "  dist/MacCleanKit.dmg"
echo "  dist/appcast-template.xml"
