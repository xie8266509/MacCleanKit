#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

Scripts/run-tests.sh
Scripts/package-dmg.sh

if [[ "${MAKE_APPCAST:-1}" == "1" ]]; then
  Scripts/make-appcast-template.sh
fi

codesign --verify --deep --strict --verbose=2 dist/MacCleanKit.app
spctl -a -vv -t execute dist/MacCleanKit.app || true

echo "Release check completed."
