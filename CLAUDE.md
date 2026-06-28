# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An Android app for **Lyndrix**, built as a [Capacitor](https://capacitorjs.com/) **native WebView
shell** that **remote-loads** the Lyndrix UI from a runtime-configurable server origin. No frontend
code lives here — the UI is `lyndrix-ui`, so every `lyndrix-ui` deploy is reflected without
rebuilding the APK. (This replaced an earlier Bubblewrap TWA; see CHANGELOG.)

The defining trick: `lyndrix-ui` calls its backend via **same-origin relative `/api/...`** URLs, so
the origin the WebView loads *is* the backend. Switching the origin therefore retargets UI + backend
together — same-origin, no CORS, no auth-cookie rework. That switch is exposed as a native-only
**Settings → App** tab inside `lyndrix-ui`.

One Capacitor project produces **two installable flavors**:

| Flavor | applicationId | Default origin (`DEFAULT_SERVER_URL`) | App name |
|---|---|---|---|
| **prod** | `de.famfeser.lyndrix` | `https://mngm.int.fam-feser.de` | Lyndrix |
| **dev** | `de.famfeser.lyndrix.dev` | `https://ui.dev.int.fam-feser.de` | Lyndrix Dev |

Both can coexist on one device. **prod's `applicationId` must never change** — same id + same
keystore is what lets existing installs update in place.

## Source of truth & what's generated

- **`capacitor.config.ts`** — the hand-edited source of truth (replaces the old `twa-manifest.json`).
  Its `server.url` is only the *compiled-in fallback*; the real default per flavor comes from
  `DEFAULT_SERVER_URL`, and the runtime value comes from `SharedPreferences`.
- **`android/`** — the Capacitor-generated native project, **committed** (Capacitor convention). It
  carries its own `android/.gitignore` for build outputs, copied web assets, and generated config.
  After editing `capacitor.config.ts`, run `npx cap sync android` to regenerate the generated parts.
  Hand-written native code lives in `android/app/src/main/java/de/famfeser/lyndrix/` (see below) and
  `android/app/build.gradle` (flavors/signing) — those are intentionally edited.
- **`www/index.html`** — a tiny stub Capacitor requires as `webDir`. Shown only if the remote origin
  is unreachable; also the reserved future offline app-shell.
- **`version.py`** — must match the git tag (CI guards it).

> ⚠️ Do not add unanchored ignore rules (`app/`, `gradle/`, `build.gradle`, …) to the **root**
> `.gitignore` — they would wrongly ignore the committed `android/` tree.

## Runtime backend switching (the core mechanism)

Two hand-written native files under `android/app/src/main/java/de/famfeser/lyndrix/`:

- **`MainActivity.java`** — before `super.onCreate()`, reads the persisted `serverUrl` (falling back
  to `BuildConfig.DEFAULT_SERVER_URL`) and injects it via `new CapConfig.Builder(this)
  .setServerUrl(url)…create()` into the protected `config` field. `BridgeActivity.onCreate()` then
  builds the bridge against that host.
- **`BackendSwitcherPlugin.java`** (`@CapacitorPlugin(name = "BackendSwitcher")`) — `getServerUrl`,
  `setServerUrl` (validate https → persist → `activity.recreate()`), `resetServerUrl`, `getInfo`.

**Capacitor gotcha that dictates this design:** on Android the bridge binds **only** to the host
configured as the bridge's `serverUrl`. Hosts reached via `server.allowNavigation` or a raw
`webView.loadUrl(...)` are detected as `web` and plugin calls throw "not implemented on android".
So switching backend is **persist new origin → `recreate()` the Activity → rebuild config**, never an
in-WebView navigation. Do not refactor it into `loadUrl`/`allowNavigation`.

The JS side lives in `lyndrix-ui`: `src/lib/nativeBridge.ts` (typed `BackendSwitcher` wrapper +
`isNativeApp()`), a conditional entry in `src/pages/settings/registry.ts`, and
`src/pages/settings/sections/NativeSettingsSection.tsx`. The native tab only renders when
`Capacitor.isNativePlatform()` is true, so the same `lyndrix-ui` bundle is unchanged in a browser.

## Build (local)

Prereqs: **JDK 21** (Capacitor 7's Android template compiles to Java 21 — JDK 17 cannot build it),
**Android SDK** (platform 35), **Node 20+**. No internal-host network access is needed (the UI loads
at runtime, not build time).

```bash
ANDROID_KEYSTORE_PASSWORD=... ANDROID_KEY_PASSWORD=... ./build.sh
# -> android/app/build/outputs/apk/{prod,dev}/release/*.apk
```

`build.sh`: `npm ci` → `npx cap sync android` → `cd android && ./gradlew assembleProdRelease
assembleDevRelease`. The same `android.keystore` (alias `lyndrix`) signs both flavors.

Useful flavored Gradle tasks: `assembleProdDebug`, `assembleDevRelease`, `bundleProdRelease`, etc.

## Release (CI / tag-driven)

```bash
# 1. Bump version.py + CHANGELOG.md, commit
# 2. ./release_tag.py --version 0.2.0
```

`.github/workflows/release.yml` fires on `v*.*.*` tags. It uses **JDK 21 + Node 20** on a
**GitHub-hosted** runner (internal-host access no longer required), guards tag↔`version.py`, exports
`APP_VERSION_NAME`/`APP_VERSION_CODE` into the Gradle env, builds both flavors, and attaches both
APKs to the Release.

CI secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`.

## Signing & identity

`android/app/build.gradle` reads signing material from env (`ANDROID_KEYSTORE_PATH` default
`../../android.keystore`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` default `lyndrix`,
`ANDROID_KEY_PASSWORD`). Release builds are left unsigned if no password is present (so local debug
builds work without secrets). `versionName`/`versionCode` come from `APP_VERSION_NAME`/
`APP_VERSION_CODE` env (CI sets them from the tag/run-number).

**Losing `android.keystore` or changing prod's `applicationId` permanently breaks updates for
installed users.** No `assetlinks.json` is needed (that was TWA-only).

> Capacitor logs a "server.url is not recommended for production" warning — that is **Apple App
> Store review only** and does not apply to this Android sideload/GitHub-Release app.

## Offline extension point (future, not in v1)

The app currently needs network to load the UI. Offline slots into three prepared seams without
changing the v1 architecture: (a) `www/index.html` becomes a real cached app-shell; (b) add
`@capacitor/filesystem` + `@capacitor/preferences` and have `MainActivity` fall back from the remote
`serverUrl` to a local `setServerBasePath` bundle when the host is unreachable; (c) the disabled
"Offline mode" card in `NativeSettingsSection.tsx` becomes the per-plugin offline UI.
