#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP="$ROOT_DIR/dist/MacCleanKit.app.zip"
OUT="$ROOT_DIR/dist/appcast-template.xml"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
DOWNLOAD_URL="${DOWNLOAD_URL:-https://example.com/MacCleanKit.app.zip}"
SPARKLE_SIGNATURE="${SPARKLE_SIGNATURE:-}"

if [[ ! -f "$ZIP" ]]; then
  echo "Missing $ZIP. Run Scripts/package-app.sh first." >&2
  exit 2
fi

SIZE="$(stat -f%z "$ZIP")"
PUBDATE="$(LC_ALL=C date '+%a, %d %b %Y %H:%M:%S %z')"

cat > "$OUT" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MacCleanKit Updates</title>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <enclosure url="$DOWNLOAD_URL" sparkle:version="$BUILD" sparkle:shortVersionString="$VERSION" length="$SIZE" type="application/octet-stream"$(if [[ -n "$SPARKLE_SIGNATURE" ]]; then printf ' sparkle:edSignature="%s"' "$SPARKLE_SIGNATURE"; fi)/>
    </item>
  </channel>
</rss>
XML

echo "Wrote $OUT"
