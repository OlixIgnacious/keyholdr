#!/bin/bash
# Renders slides.html to 2880x1800 PNGs (App Store Connect Mac size) plus smaller sizes.
# Usage: ./render.sh   (needs Google Chrome; fonts load from Google Fonts)
set -euo pipefail
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT=export; mkdir -p "$OUT"
for n in 1 2 3 4 5; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1440,900 --force-device-scale-factor=2 \
    --virtual-time-budget=6000 \
    --screenshot="$OUT/$n-2880x1800.png" "file://$PWD/slides.html?s=$n" >/dev/null 2>&1
  for size in 2560x1600 1440x900 1280x800; do
    w=${size%x*}; h=${size#*x}
    mkdir -p "$OUT/$size"
    sips -z "$h" "$w" "$OUT/$n-2880x1800.png" --out "$OUT/$size/keyholdr-$n.png" >/dev/null
  done
done
echo "done → $PWD/$OUT"
