#!/usr/bin/env bash
# Builds a universal (arm64 + x86_64) build/VapeCalc.app, ad-hoc signed.
set -euo pipefail

cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
APP="build/VapeCalc.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/VapeCalc" "$APP/Contents/MacOS/VapeCalc"
cp -R "$BIN_PATH/VapeCalc_VapeCalcCore.bundle" "$APP/Contents/Resources/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

echo "Built $APP"
