# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/) · SemVer. The version here
MUST match the git tag cut via `release_tag.py` (CI guards `version.py == tag`).

## [Unreleased]
### Changed
- **Migrated from a Bubblewrap TWA to a Capacitor native shell.** The app now remote-loads the
  Lyndrix UI from a runtime-configurable server origin instead of being a fixed browser shell.
  Source of truth moves from `twa-manifest.json` to `capacitor.config.ts` + a committed `android/`
  project.
- CI/build now needs **JDK 21 + Node 20+** (Capacitor 7) and no longer needs network access to the
  internal host; the `release-apk` workflow can run on a GitHub-hosted runner and builds both
  flavors.
### Added
- **Runtime backend switching** via `BackendSwitcherPlugin` (persists the chosen origin and
  rebinds the bridge on `recreate()`), surfaced as a native-only **Settings → App** tab in
  `lyndrix-ui`. Switching the origin retargets UI + backend together (same-origin, no CORS/auth
  changes).
- **prod / dev Gradle product flavors** (`de.famfeser.lyndrix` / `…​.dev`) replacing the duplicated
  `dev/` TWA tree; each compiles in its own `DEFAULT_SERVER_URL`.
### Removed
- `twa-manifest.json`, the `dev/` TWA variant, and the Digital Asset Link requirement
  (`assetlinks.json` in `lyndrix-ui` is no longer needed).

## [0.1.0] - 2026-06-26
### Added
- Initial Bubblewrap **TWA** wrapping the hosted Lyndrix PWA
  (`https://lyndrix.int.fam-feser.de`) into an Android APK.
- `twa-manifest.json` (packageId `de.famfeser.lyndrix`, standalone, brand colors).
- `build.sh` for local/network-connected builds; tag-driven GitHub Actions
  release workflow (self-hosted runner) that signs + attaches the APK to the Release.
- `version.py` + `release_tag.py` for consistent, deliberate version cuts.
