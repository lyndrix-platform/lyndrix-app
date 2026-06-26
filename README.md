# lyndrix-app

Android app for **Lyndrix** — a [Bubblewrap](https://github.com/GoogleChromeLabs/bubblewrap)
**TWA** (Trusted Web Activity) that wraps the hosted PWA at
`https://lyndrix.int.fam-feser.de` 1:1. The app is a thin native shell around the
live SPA, so it stays same-origin and auto-reflects every `lyndrix-ui` deploy — no
app rebuild needed for frontend changes.

> The PWA side (manifest, service worker, icons, `assetlinks.json`) lives in
> **`lyndrix-ui`**. This repo only builds + ships the APK.

## Prerequisites
- A machine/runner that can **reach `lyndrix.int.fam-feser.de`** (Bubblewrap fetches
  the web manifest + icons at build time — GitHub-hosted runners can't, so CI uses a
  **self-hosted** runner).
- **JDK 17**, **Android SDK** (cmdline-tools + build-tools + platform), **Node**.
- A **signing keystore** (see below).

## One-time: create the signing key + Digital Asset Link
```bash
keytool -genkeypair -v -keystore android.keystore -alias lyndrix \
  -keyalg RSA -keysize 2048 -validity 9125 -storetype PKCS12
# Get the SHA256 fingerprint:
keytool -list -v -keystore android.keystore -alias lyndrix | grep 'SHA256:'
```
Put that SHA256 into **lyndrix-ui** `public/.well-known/assetlinks.json`
(`sha256_cert_fingerprints`) and deploy lyndrix-ui — this verifies the domain and
removes the URL bar in the TWA.

> Keep `android.keystore` **out of git** (it's gitignored). Back it up safely — losing
> it means you can't ship updates under the same app identity.

## Build locally (most reliable first run)
```bash
BUBBLEWRAP_KEYSTORE_PASSWORD=... BUBBLEWRAP_KEY_PASSWORD=... ./build.sh
# -> app-release-signed.apk
```
Install/sideload the APK on the device (`adb install app-release-signed.apk`, or copy
it over). On first launch it opens the Lyndrix SPA full-screen.

## Release via CI (tag-driven)
1. Configure repo **Actions secrets**: `ANDROID_KEYSTORE_BASE64` (`base64 -w0 android.keystore`),
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`.
2. Ensure a **self-hosted** GitHub runner (label `self-hosted, linux`) with Node +
   network access to the internal host is online.
3. Bump `version.py`, update `CHANGELOG.md`, commit, then cut the release:
   ```bash
   ./release_tag.py --version 0.1.0
   ```
   The `release-apk` workflow builds the signed APK and attaches it to the GitHub
   Release for that tag. Users sideload it from the Release assets.

## Config
- App identity: `packageId` `de.famfeser.lyndrix` in `twa-manifest.json` (must match the
  `assetlinks.json` `package_name`). Changing it creates a new app identity.
- Target site: `host` / `*Url` fields in `twa-manifest.json`.
- `versionName`/`versionCode` are injected from the git tag + run number in CI.

## Notes
- TWA needs the site served over a **publicly-trusted TLS cert** (you have it via ionos)
  so Android accepts it.
- Background **push notifications** are not enabled here (`enableNotifications: false`).
  If you want them later, that's the point to switch to a Capacitor shell with native FCM.
- The exact Bubblewrap CLI flags may need a tweak on the very first project generation
  depending on the installed `@bubblewrap/cli` version (this repo ships the manifest, not
  the generated Android project).
