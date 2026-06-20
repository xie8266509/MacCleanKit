#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build
swift run MacCleanKit --self-test

if [[ "${SKIP_UI_SMOKE:-0}" != "1" ]]; then
  Scripts/package-app.sh
  Scripts/smoke-launch.sh
fi
