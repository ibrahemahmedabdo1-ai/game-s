#!/usr/bin/env bash
# Usage: scripts/ci_build.sh <game_dir_name> <apk-debug|apk-release|aab>
# Output: release/<game>/...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$1"; MODE="$2"
APP="$ROOT/apps/$GAME"
OUT="$ROOT/release/$GAME"; mkdir -p "$OUT"
"$ROOT/scripts/prepare_android.sh" "$APP"
cd "$APP"
flutter pub get
SIGNED=false; [ -f android/key.properties ] && SIGNED=true
DEFS=(--dart-define=ADMOB_ENV=production
  "--dart-define=ADMOB_APP_ID=${ADMOB_APP_ID:-ADMOB_APP_ID}"
  "--dart-define=ADMOB_BANNER_ID=${ADMOB_BANNER_ID:-ADMOB_BANNER_ID}"
  "--dart-define=ADMOB_INTERSTITIAL_ID=${ADMOB_INTERSTITIAL_ID:-ADMOB_INTERSTITIAL_ID}"
  "--dart-define=ADMOB_REWARDED_ID=${ADMOB_REWARDED_ID:-ADMOB_REWARDED_ID}")
case "$MODE" in
  apk-debug)
    flutter build apk --debug --dart-define=ADMOB_ENV=development
    cp build/app/outputs/flutter-apk/app-debug.apk "$OUT/app-debug.apk" ;;
  apk-release)
    if [ "$SIGNED" != true ]; then
      echo "SKIPPED release APK for $GAME: no signing secrets (not producing a fake signed file)."
      echo "Release APK skipped: signing secrets not configured." > "$OUT/RELEASE_APK_SKIPPED.txt"
      exit 0
    fi
    flutter build apk --release "${DEFS[@]}"
    cp build/app/outputs/flutter-apk/app-release.apk "$OUT/app-release.apk" ;;
  aab)
    flutter build appbundle --release "${DEFS[@]}"
    if [ "$SIGNED" = true ]; then
      cp build/app/outputs/bundle/release/app-release.aab "$OUT/app-release.aab"
    else
      cp build/app/outputs/bundle/release/app-release.aab "$OUT/app-release-UNSIGNED.aab"
      echo "This AAB is NOT signed. Add signing secrets or sign it before uploading." > "$OUT/AAB_UNSIGNED.txt"
    fi ;;
  *) echo "unknown mode $MODE"; exit 2 ;;
esac
