# Distributing Without an Apple Developer Account

Without an Apple Developer Program membership, MacCleanKit cannot be Developer ID signed or notarized. Browser-downloaded builds may show:

```text
"MacCleanKit" is damaged and can't be opened.
```

This is macOS Gatekeeper blocking a non-notarized downloaded app.

## Recommended Positioning

Treat GitHub-hosted artifacts as trusted test builds, not public production releases.

Recommended release wording:

```text
This is an ad-hoc signed test build. macOS may block it after download because it is not Developer ID notarized. Only install it if you trust this repository.
```

## Tester Install

After downloading the DMG:

1. Open `MacCleanKit.dmg`.
2. Drag `MacCleanKit.app` to `/Applications`.
3. Run:

```bash
xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
open /Applications/MacCleanKit.app
```

If needed:

```bash
sudo xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
open /Applications/MacCleanKit.app
```

## Repository Helper

From the repository root:

```bash
Scripts/install-test-build.sh dist/MacCleanKit.app
```

Or mount the DMG first, then run:

```bash
Scripts/install-test-build.sh /Volumes/MacCleanKit/MacCleanKit.app
```

## What This Does Not Solve

This does not create a notarized public macOS release. The only long-term solution for ordinary users is Apple Developer ID signing plus notarization.
