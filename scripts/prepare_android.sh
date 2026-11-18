#!/usr/bin/env bash
# Generates apps/<game>/android with `flutter create`, then applies our manifest,
# gradle config (target SDK 36, signing, AdMob placeholder) and launcher icons.
# Usage: scripts/prepare_android.sh apps/color_reactor
set -euo pipefail
APP_DIR="$(cd "$1" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$(basename "$APP_DIR")"
# shellcheck disable=SC1091
source "$APP_DIR/app.properties"
ORG="${APP_ID%.*}"; NAME="${APP_ID##*.}"

cd "$APP_DIR"
if [ ! -d android ]; then
  flutter create --platforms=android --org "$ORG" --project-name "$NAME" .
fi
# flutter create can drop a default widget test that does not match our app.
rm -f test/widget_test.dart
sed "s|__APP_ID__|$APP_ID|g" "$ROOT/android_templates/build.gradle.kts.tmpl" > android/app/build.gradle.kts
rm -f android/app/build.gradle
sed -e "s|__APP_LABEL__|$APP_LABEL|g" "$ROOT/android_templates/AndroidManifest.xml.tmpl" > android/app/src/main/AndroidManifest.xml
cp "$ROOT/android_templates/proguard-rules.pro" android/app/proguard-rules.pro
# Launcher icons: legacy PNGs + Android 8+ adaptive icon (foreground PNG + background color)
ICONS="$ROOT/store_assets/$GAME/icons"
RES=android/app/src/main/res
if [ -d "$ICONS" ]; then
  for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    mkdir -p "$RES/mipmap-$d" "$RES/drawable-$d"
    cp "$ICONS/ic_launcher_$d.png" "$RES/mipmap-$d/ic_launcher.png"
    cp "$ICONS/adaptive_foreground_$d.png" "$RES/drawable-$d/ic_launcher_foreground.png"
  done
  mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values"
  cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
XML
  cat > "$RES/values/ic_launcher_background.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="ic_launcher_background">${ICON_BG:-#222222}</color></resources>
XML
fi
# Signing file from CI secrets (never committed).
if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks
  cat > android/key.properties <<KP
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=upload-keystore.jks
KP
  echo "Signing configured from secrets."
else
  echo "No signing secrets: release APKs will be skipped, AABs will be UNSIGNED."
fi
