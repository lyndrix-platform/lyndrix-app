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

# ---------------------------------------------------------------------------
# Android SDK — auto-detect from local.properties if ANDROID_HOME is unset
# ---------------------------------------------------------------------------
if [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  LP="$SCRIPT_DIR/android/local.properties"
  if [ -f "$LP" ]; then
    SDK_FROM_LP="$(grep '^sdk\.dir=' "$LP" | head -1 | cut -d= -f2- | tr -d '\r')"
    if [ -n "$SDK_FROM_LP" ] && [ -d "$SDK_FROM_LP" ]; then
      export ANDROID_HOME="$SDK_FROM_LP"
      export ANDROID_SDK_ROOT="$SDK_FROM_LP"
      echo "ℹ  ANDROID_HOME auto-detected from local.properties: $ANDROID_HOME"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Version → Gradle. Defaults to version.py when not injected by CI.
# ---------------------------------------------------------------------------
export APP_VERSION_NAME="${APP_VERSION_NAME:-$(python3 -c 'import version; print(version.__version__)')}"
export APP_VERSION_CODE="${APP_VERSION_CODE:-1}"

# Signing passwords are read by android/app/build.gradle from these names.
# Gradle checks `keystorePassword != null` — an empty string is not null, so we
# must fully unset the variables (not just set them to "") when no password is
# given; that way Gradle's `System.getenv(...)` returns null and skips signing.
if [ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
  export ANDROID_KEYSTORE_PASSWORD
  export ANDROID_KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"
else
  unset ANDROID_KEYSTORE_PASSWORD
  unset ANDROID_KEY_PASSWORD
  echo "⚠  No ANDROID_KEYSTORE_PASSWORD set — APKs will be unsigned (not installable on prod devices)."
  echo "   Signed build:  ANDROID_KEYSTORE_PASSWORD=... ANDROID_KEY_PASSWORD=... ./build.sh"
fi

# ---------------------------------------------------------------------------
# JS sync
# ---------------------------------------------------------------------------
npm ci
npx cap sync android

# ---------------------------------------------------------------------------
# Gradle build
# ---------------------------------------------------------------------------
cd android
./gradlew assembleProdRelease assembleDevRelease

# ---------------------------------------------------------------------------
# Rename APKs to include version for easy identification
# ---------------------------------------------------------------------------
cd ..
echo
echo "APKs:"
for APK in android/app/build/outputs/apk/prod/release/*.apk \
            android/app/build/outputs/apk/dev/release/*.apk; do
  [ -f "$APK" ] || continue
  FLAVOR="$(echo "$APK" | grep -oP '/(prod|dev)/' | tr -d '/')"
  DEST="lyndrix-${APP_VERSION_NAME}-${FLAVOR}.apk"
  cp "$APK" "$DEST"
  echo "  $DEST  ($(du -sh "$DEST" | cut -f1))"
done
