#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT_NAME="MacCleanKit"
APP_NAME="MacCleanKit"
BUNDLE_ID="${BUNDLE_ID:-com.local.maccleankit}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
VERSION="${VERSION:-0.1.3}"
BUILD="${BUILD:-4}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift Scripts/generate-icon.swift
swift build -c release --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/$PRODUCT_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
if [[ -d "$BIN_DIR/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle" ]]; then
  cp -R "$BIN_DIR/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle" "$CONTENTS_DIR/Resources/"
  find "$CONTENTS_DIR/Resources/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle" -name Localizable.strings -delete
  find "$CONTENTS_DIR/Resources/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle" -type d -empty -delete
fi
cp "$ROOT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>NSHumanReadableCopyright</key>
    <string>Author: Linux do @MIKE2026</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
PLIST

if [[ -n "$SPARKLE_FEED_URL" ]]; then
cat >> "$CONTENTS_DIR/Info.plist" <<PLIST
    <key>SUFeedURL</key>
    <string>$SPARKLE_FEED_URL</string>
PLIST
fi

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
cat >> "$CONTENTS_DIR/Info.plist" <<PLIST
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_ED_KEY</string>
PLIST
fi

cat >> "$CONTENTS_DIR/Info.plist" <<PLIST
</dict>
</plist>
PLIST

codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_DIR"
ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/$APP_NAME.app.zip"

echo "Built $APP_DIR"
echo "Archive $DIST_DIR/$APP_NAME.app.zip"
