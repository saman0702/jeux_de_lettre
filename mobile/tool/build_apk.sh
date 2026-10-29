#!/usr/bin/env bash
# Build APK release Letter Race — API prod par défaut.
#
# Usage :
#   ./tool/build_apk.sh              # APK unique (toutes archis)
#   ./tool/build_apk.sh --split      # un APK par architecture
#   API_BASE_URL=http://192.168.1.10:8010 ./tool/build_apk.sh   # override
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://gamelr-api.optisoftw.com}"
SPLIT=0

for arg in "$@"; do
  case "$arg" in
    --split|--split-per-abi) SPLIT=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *)
      echo "Option inconnue: $arg" >&2
      exit 1
      ;;
  esac
done

echo "==> API_BASE_URL=$API_BASE_URL"
echo "==> flutter build apk --release${SPLIT:+ --split-per-abi}"

ARGS=(build apk --release "--dart-define=API_BASE_URL=${API_BASE_URL}")
if [ "$SPLIT" -eq 1 ]; then
  ARGS+=(--split-per-abi)
fi

flutter "${ARGS[@]}"

OUT="$ROOT/build/app/outputs/flutter-apk"
echo "==> APK :"
ls -lh "$OUT"/app-*-release.apk "$OUT"/app-release.apk 2>/dev/null || ls -lh "$OUT"/*.apk
