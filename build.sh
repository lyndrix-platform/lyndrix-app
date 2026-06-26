#!/usr/bin/env bash
# Build the signed Lyndrix TWA APK from twa-manifest.json.
#
# Run on a machine that (a) can reach https://mngm.int.fam-feser.de and
# (b) has JDK 17 + Android SDK + Node. Bubblewrap regenerates the Android project
# from twa-manifest.json, then builds + signs.
#
# Keystore: expects ./android.keystore (alias 'lyndrix'). Create once with:
#   keytool -genkeypair -v -keystore android.keystore -alias lyndrix \
#     -keyalg RSA -keysize 2048 -validity 9125 -storetype PKCS12
# Pass passwords via env so this stays non-interactive:
#   BUBBLEWRAP_KEYSTORE_PASSWORD=... BUBBLEWRAP_KEY_PASSWORD=... ./build.sh
set -euo pipefail

command -v bubblewrap >/dev/null 2>&1 || npm i -g @bubblewrap/cli

# Regenerate the Android project from the committed manifest, then build.
bubblewrap update --skipVersionUpgrade || true
bubblewrap build --skipPwaValidation

echo
echo "APK(s):"
ls -1 ./*.apk 2>/dev/null || echo "  (none — check the build output above)"
echo
echo "Signing-key SHA256 (put this into lyndrix-ui /.well-known/assetlinks.json):"
keytool -list -v -keystore android.keystore -alias lyndrix 2>/dev/null \
  | grep -i 'SHA256:' || echo "  run: keytool -list -v -keystore android.keystore -alias lyndrix"
