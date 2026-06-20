#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/MacCleanKit.app}"
CAPTURE_PATH="${SMOKE_CAPTURE_PATH:-/tmp/maccleankit-smoke.png}"
EXECUTABLE="$APP_PATH/Contents/MacOS/MacCleanKit"

if [[ ! -x "$EXECUTABLE" ]]; then
  "$ROOT_DIR/Scripts/package-app.sh"
fi

cleanup() {
  pgrep -f "$EXECUTABLE" | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

cleanup
rm -f "$CAPTURE_PATH"
"$EXECUTABLE" --capture-ui "$CAPTURE_PATH"

if [[ ! -s "$CAPTURE_PATH" ]]; then
  echo "UI capture failed: $CAPTURE_PATH was not created." >&2
  exit 1
fi

WIDTH="$(sips -g pixelWidth "$CAPTURE_PATH" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
HEIGHT="$(sips -g pixelHeight "$CAPTURE_PATH" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
if [[ "${WIDTH:-0}" -lt 900 || "${HEIGHT:-0}" -lt 600 ]]; then
  echo "UI capture has unexpected dimensions: ${WIDTH:-0}x${HEIGHT:-0}" >&2
  exit 1
fi

open -n "$APP_PATH"
sleep "${SMOKE_LAUNCH_DELAY:-4}"

swift - <<'SWIFT'
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo(CGWindowListOption(arrayLiteral: .optionAll), kCGNullWindowID) as? [[String: Any]] ?? []
let visible = windows.contains { window in
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    guard owner.contains("MacCleanKit") else { return false }
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    return width >= 900 && height >= 600
}

if visible {
    print("Launch smoke test passed.")
    exit(0)
}

print("Launch smoke test failed: no visible MacCleanKit window >= 900x600.")
exit(1)
SWIFT
