#!/usr/bin/env bash
# Renders Resources/AppIcon.icns from Tools/make_icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET" Resources

for size in 16 32 64 128 256 512 1024; do
	swift Tools/make_icon.swift "$ICONSET/render-$size.png" "$size" >/dev/null
done

cp "$ICONSET/render-16.png"   "$ICONSET/icon_16x16.png"
cp "$ICONSET/render-32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/render-32.png"   "$ICONSET/icon_32x32.png"
cp "$ICONSET/render-64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/render-128.png"  "$ICONSET/icon_128x128.png"
cp "$ICONSET/render-256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/render-256.png"  "$ICONSET/icon_256x256.png"
cp "$ICONSET/render-512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/render-512.png"  "$ICONSET/icon_512x512.png"
cp "$ICONSET/render-1024.png" "$ICONSET/icon_512x512@2x.png"
rm "$ICONSET"/render-*.png

iconutil --convert icns "$ICONSET" --output Resources/AppIcon.icns
echo "Built Resources/AppIcon.icns"
