#!/usr/bin/env bash
# Build APK release Mind Race (tests sideload / hors Play Store).
# Incrémente automatiquement le code de version dans pubspec.yaml.
#
# Usage :
#   ./scripts/build_release_apk.sh
#   SKIP_CLEAN=1 ./scripts/build_release_apk.sh
# Les IDs AdMob sont dans scripts/admob_defaults.sh (surcharge env possible).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=admob_defaults.sh
source "$ROOT/scripts/admob_defaults.sh"

API_BASE_URL="${API_BASE_URL:-https://gamelr-api.optisoftw.com}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"
APP_SLUG="mind-race"

if [[ ! -f "$ROOT/android/key.properties" ]]; then
  echo "AVERTISSEMENT: android/key.properties absent — APK signé avec la clé debug."
fi

CURRENT_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_NAME="${CURRENT_VERSION%+*}"
BUILD_NUMBER="${CURRENT_VERSION#*+}"

if [[ "$CURRENT_VERSION" != *+* || ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERREUR: version invalide dans pubspec.yaml : « $CURRENT_VERSION »"
  exit 1
fi

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD_NUMBER}"

sed -i.bak "s/^version:.*/version: ${NEW_VERSION}/" pubspec.yaml
rm -f pubspec.yaml.bak

echo "==> Build APK Mind Race"
echo "    API_BASE_URL=$API_BASE_URL"
echo "    version ${CURRENT_VERSION} → ${NEW_VERSION}"
echo "    ADMOB_APP_ID=$ADMOB_APP_ID"
echo "    ADMOB_INTERSTITIAL_ANDROID=$ADMOB_INTERSTITIAL_ANDROID"

if [[ "$SKIP_CLEAN" != "1" ]]; then
  flutter clean
fi
flutter pub get

BUILD_ARGS=(
  build apk
  --release
  --build-name="$VERSION_NAME"
  --build-number="$NEW_BUILD_NUMBER"
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "-PADMOB_APP_ID=$ADMOB_APP_ID"
  "--dart-define=ADMOB_REWARDED_ANDROID=$ADMOB_REWARDED_ANDROID"
  "--dart-define=ADMOB_INTERSTITIAL_ANDROID=$ADMOB_INTERSTITIAL_ANDROID"
)

flutter "${BUILD_ARGS[@]}"

FLUTTER_APK_DIR="$ROOT/build/app/outputs/flutter-apk"
SRC=""
for candidate in \
  "$FLUTTER_APK_DIR/app-release.apk" \
  "$FLUTTER_APK_DIR/${APP_SLUG}-release.apk"; do
  if [[ -f "$candidate" ]]; then
    SRC="$candidate"
    break
  fi
done

if [[ -z "$SRC" ]]; then
  echo "ERREUR: APK non trouvé. Annulation de l'incrément version…"
  sed -i.bak "s/^version:.*/version: ${CURRENT_VERSION}/" pubspec.yaml
  rm -f pubspec.yaml.bak
  ls -la "$FLUTTER_APK_DIR" 2>/dev/null || true
  exit 1
fi

mkdir -p "$ROOT/dist"
DEST="$ROOT/dist/${APP_SLUG}-${NEW_VERSION}.apk"
cp -f "$SRC" "$DEST"
cp -f "$SRC" "$ROOT/dist/${APP_SLUG}-release.apk"

ls -lh "$DEST"
echo ""
echo "OK — APK prêt (versionCode ${NEW_BUILD_NUMBER}) :"
echo "  $DEST"
