#!/usr/bin/env bash
# Rend les 6 captures des stores dans assets/branding/store/ :
#   play/    Google Play, 1080 × 1920 (9:16)
#   ios_6.9/ App Store, iPhone 6,9 po (1290 × 2796)
#   ios_6.5/ App Store, iPhone 6,5 po (1242 × 2688)
# Les écrans de l'appli (*.png de ce dossier) viennent des tests Flutter (pixelRatio 3).
set -euo pipefail
cd "$(dirname "$0")"
render() {
  local dir=../../assets/branding/store/$1 w=$2 h=$3
  mkdir -p "$dir"
  for n in 1 2 3 4 5 6; do
    google-chrome --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
      --window-size="$w,$h" --virtual-time-budget=3000 \
      --screenshot="$dir/capture_$n.png" "file://$PWD/frame.html?n=$n&w=$w&h=$h" 2>/dev/null
  done
}
render play 1080 1920
render ios_6.9 1290 2796
render ios_6.5 1242 2688
