#!/usr/bin/env bash
# Build the signed Lyndrix APKs (prod + dev) from the Capacitor project.
#
# Prereqs: JDK 21, Android SDK (cmdline-tools + build-tools + platform 35), Node 20+.
#   (Capacitor 7's Android template compiles to Java 21 — JDK 17 will NOT build it.)
#
# Keystore: expects ./android.keystore (alias 'lyndrix'). Pass passwords via env so this stays
# non-interactive. The same key signs both flavors (their applicationIds differ: …lyndrix vs ….dev):
#   ANDROID_KEYSTORE_PASSWORD=... ANDROID_KEY_PASSWORD=... ./build.sh
#
# Unlike the old Bubblewrap flow, the build fetches nothing from the internal Lyndrix host — the app
# loads the UI from its server origin at RUNTIME, not build time.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Version → Gradle. Defaults to version.py when not injected by CI.
export APP_VERSION_NAME="${APP_VERSION_NAME:-$(python3 -c 'import version; print(version.__version__)')}"
export APP_VERSION_CODE="${APP_VERSION_CODE:-1}"

# Signing passwords are read by android/app/build.gradle from these names.
export ANDROID_KEYSTORE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:-}"
export ANDROID_KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"

command -v cap >/dev/null 2>&1 || true
npm ci
npx cap sync android

cd android
./gradlew assembleProdRelease assembleDevRelease

echo
echo "APKs:"
find app/build/outputs/apk -name '*-release.apk' 2>/dev/null || echo "  (none — check the build output above)"
