#!/usr/bin/env bash
# Build Android App Bundle (.aab) pour Google Play — Mind Race.
# Incrémente automatiquement le code de version dans pubspec.yaml (ex. 1.0.0+3 → 1.0.0+4).
#
# Usage :
#   ./scripts/build_playstore_aab.sh
#   API_BASE_URL=https://… ./scripts/build_playstore_aab.sh
#   SKIP_CLEAN=1 ./scripts/build_playstore_aab.sh          # sans flutter clean
# Les IDs AdMob sont dans scripts/admob_defaults.sh (surcharge env possible).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=admob_defaults.sh
source "$ROOT/scripts/admob_defaults.sh"

API_BASE_URL="${API_BASE_URL:-https://gamelr-api.optisoftw.com}"
SKIP_CLEAN="${SKIP_CLEAN:-0}"

KEY_PROPS="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]]; then
  echo "ERREUR: android/key.properties manquant (signature Play Store)."
  echo "Voir docs/ETAPES_GOOGLE_PLAY.md § clé d'envoi."
  exit 1
fi

# ── Incrément du build number (versionCode Play) ─────────────────────
# Format pubspec : version: <versionName>+<versionCode>  (ex. 1.0.0+3)
CURRENT_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_NAME="${CURRENT_VERSION%+*}"
BUILD_NUMBER="${CURRENT_VERSION#*+}"

if [[ "$CURRENT_VERSION" != *+* || ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERREUR: version invalide dans pubspec.yaml : « $CURRENT_VERSION »"
  echo "Attendu : 1.0.0+N"
  exit 1
fi

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NAME}+${NEW_BUILD_NUMBER}"

sed -i.bak "s/^version:.*/version: ${NEW_VERSION}/" pubspec.yaml
rm -f pubspec.yaml.bak

echo "==> Build AAB Mind Race (Play Store)"
echo "    API_BASE_URL=$API_BASE_URL"
echo "    version ${CURRENT_VERSION} → ${NEW_VERSION}  (versionCode=${NEW_BUILD_NUMBER})"
echo "    ADMOB_APP_ID=$ADMOB_APP_ID"
echo "    ADMOB_REWARDED_ANDROID=$ADMOB_REWARDED_ANDROID"
echo "    ADMOB_INTERSTITIAL_ANDROID=$ADMOB_INTERSTITIAL_ANDROID"

if [[ "$SKIP_CLEAN" != "1" ]]; then
  flutter clean
fi
flutter pub get

BUILD_ARGS=(
  build appbundle
  --release
  --build-name="$VERSION_NAME"
  --build-number="$NEW_BUILD_NUMBER"
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "-PADMOB_APP_ID=$ADMOB_APP_ID"
  "--dart-define=ADMOB_REWARDED_ANDROID=$ADMOB_REWARDED_ANDROID"
  "--dart-define=ADMOB_INTERSTITIAL_ANDROID=$ADMOB_INTERSTITIAL_ANDROID"
)

flutter "${BUILD_ARGS[@]}"

OUT="$ROOT/build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$OUT" ]]; then
  mkdir -p "$ROOT/dist"
  DEST="$ROOT/dist/mind-race-playstore-${NEW_VERSION}.aab"
  cp -f "$OUT" "$DEST"
  ls -lh "$DEST"
  echo ""
  echo "OK — AAB prêt (versionCode ${NEW_BUILD_NUMBER}) :"
  echo "  $DEST"
  echo "Uploadez-le dans Play Console → Tests internes (ou Production)."
else
  echo "ERREUR: AAB non généré. Annulation de l'incrément version…"
  sed -i.bak "s/^version:.*/version: ${CURRENT_VERSION}/" pubspec.yaml
  rm -f pubspec.yaml.bak
  exit 1
fi
