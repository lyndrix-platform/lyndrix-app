# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/) · SemVer. The version here
MUST match the git tag cut via `release_tag.py` (CI guards `version.py == tag`).

## [Unreleased]

## [0.1.0] - 2026-06-26
### Added
- Initial Bubblewrap **TWA** wrapping the hosted Lyndrix PWA
  (`https://lyndrix.int.fam-feser.de`) into an Android APK.
- `twa-manifest.json` (packageId `de.famfeser.lyndrix`, standalone, brand colors).
- `build.sh` for local/network-connected builds; tag-driven GitHub Actions
  release workflow (self-hosted runner) that signs + attaches the APK to the Release.
- `version.py` + `release_tag.py` for consistent, deliberate version cuts.
