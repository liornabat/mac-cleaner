#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
icon_source="Sources/MacClean/Resources/MacCleanIcon.png"
icon_set="$PWD/dist/MacClean.iconset"
mkdir -p "$icon_set"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$icon_source" --out "$icon_set/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z "$retina_size" "$retina_size" "$icon_source" --out "$icon_set/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_set" --output "$PWD/dist/MacClean.icns"
