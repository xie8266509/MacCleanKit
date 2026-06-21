# Install MacCleanKit

## Recommended Public Install

Public builds should be distributed as a Developer ID signed, notarized, and stapled DMG.

1. Download `MacCleanKit.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `MacCleanKit.app` to `/Applications`.
4. Open MacCleanKit from `/Applications`.

If macOS reports that the app is damaged, the downloaded build was not notarized for public distribution. Use a notarized release build instead.

## Trusted Test Build Workaround

Only use this for a test build from a trusted source:

```bash
xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
open /Applications/MacCleanKit.app
```

If the app is still blocked:

```bash
sudo xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
open /Applications/MacCleanKit.app
```

## Full Disk Access

MacCleanKit can run without Full Disk Access, but scans for Mail, Safari, browser profiles, Trash, and parts of `~/Library` may be incomplete.

Open:

```text
System Settings > Privacy & Security > Full Disk Access
```

Then enable MacCleanKit and relaunch the app.

## Verify a Release Build

For a notarized public build, these checks should pass:

```bash
spctl -a -vv -t execute /Applications/MacCleanKit.app
spctl -a -vv -t open --context context:primary-signature MacCleanKit.dmg
```
