# Distribution

MacCleanKit can be built locally with ad-hoc signing, or prepared for external distribution with Developer ID signing and Apple notarization.

## Local Test Build

```bash
Scripts/package-app.sh
```

This writes:

```text
dist/MacCleanKit.app
dist/MacCleanKit.app.zip
```

By default `CODESIGN_IDENTITY` is `-`, which means ad-hoc signing.

## Developer ID Build

Requires an Apple Developer account and a valid Developer ID Application certificate installed in the login keychain.

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
BUNDLE_ID="com.yourcompany.maccleankit" \
Scripts/package-app.sh
```

## Notarization

Create a `notarytool` profile first:

```bash
xcrun notarytool store-credentials "maccleankit-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Then submit and staple:

```bash
NOTARY_PROFILE="maccleankit-notary" Scripts/notarize-app.sh
```

For a public DMG release, notarize the app first, rebuild the DMG from the stapled app, then notarize and staple the DMG:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
BUNDLE_ID="com.yourcompany.maccleankit" \
Scripts/package-app.sh

NOTARY_PROFILE="maccleankit-notary" Scripts/notarize-app.sh
Scripts/package-dmg.sh
NOTARY_PROFILE="maccleankit-notary" Scripts/notarize-dmg.sh
```

Verify the final artifacts:

```bash
spctl -a -vv -t execute dist/MacCleanKit.app
spctl -a -vv -t open --context context:primary-signature dist/MacCleanKit.dmg
```

If macOS says the app is damaged after a browser download, the build was not notarized for public distribution. For trusted test builds only, remove the quarantine flag after copying the app to `/Applications`:

```bash
xattr -dr com.apple.quarantine /Applications/MacCleanKit.app
```

Do not use the quarantine workaround as the public distribution path. Public users should receive a Developer ID signed, notarized, stapled DMG.

## Sparkle Appcast

The app contains a Sparkle-compatible update controller behind `#if canImport(Sparkle)`. For offline local builds, Sparkle is not forced as a dependency. To enable real automatic updates in a distribution build:

1. Vendor or add Sparkle 2 from `https://github.com/sparkle-project/Sparkle`.
2. Link and embed `Sparkle.framework`.
3. Generate an EdDSA key pair using Sparkle's tools.
4. Package with `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY`.

The included script generates an appcast XML template for the packaged zip:

```bash
DOWNLOAD_URL="https://your-domain.example/MacCleanKit.app.zip" \
VERSION="0.1.2" \
Scripts/make-appcast-template.sh
```

Package with Sparkle keys:

```bash
SPARKLE_FEED_URL="https://your-domain.example/appcast.xml" \
SPARKLE_PUBLIC_ED_KEY="your-public-eddsa-key" \
Scripts/package-app.sh
```

## DMG

```bash
Scripts/package-dmg.sh
```

This creates `dist/MacCleanKit.dmg` with the app and an `/Applications` shortcut.

## Release Gate

Before sharing a build, run:

```bash
Scripts/release-check.sh
```

The release gate builds the app, runs the self-test, verifies packaged launch visibility, exports a UI screenshot via the app's internal capture mode, builds the DMG, creates an appcast template, and runs local code-signing checks. Developer ID notarization still requires a real certificate and `NOTARY_PROFILE`.
