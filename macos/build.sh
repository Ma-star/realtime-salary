#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
DIST_DIR="$SCRIPT_DIR/dist"
APP_NAME="下班回血器"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ICONSET="$BUILD_DIR/RealtimeSalary.iconset"
ICON_SOURCE="$PROJECT_DIR/ios/RealtimeSalary/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

rm -rf "$APP_BUNDLE" "$ICONSET"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$ICONSET" "$DIST_DIR"

cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/ios/RealtimeSalary/PrivacyInfo.xcprivacy" "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/RealtimeSalary.icns"

SOURCES=(
  "$PROJECT_DIR/ios/RealtimeSalary/Models.swift"
  "$PROJECT_DIR/ios/RealtimeSalary/SalaryStore.swift"
  "$SCRIPT_DIR/RealtimeSalaryMacApp.swift"
)

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk macosx swiftc \
  -parse-as-library -O -whole-module-optimization \
  -target arm64-apple-macos14.0 -module-name RealtimeSalaryMac \
  "${SOURCES[@]}" -o "$BUILD_DIR/RealtimeSalaryMac-arm64"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk macosx swiftc \
  -parse-as-library -O -whole-module-optimization \
  -target x86_64-apple-macos14.0 -module-name RealtimeSalaryMac \
  "${SOURCES[@]}" -o "$BUILD_DIR/RealtimeSalaryMac-x86_64"

lipo -create \
  "$BUILD_DIR/RealtimeSalaryMac-arm64" \
  "$BUILD_DIR/RealtimeSalaryMac-x86_64" \
  -output "$APP_BUNDLE/Contents/MacOS/RealtimeSalaryMac"

codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

rm -f "$DIST_DIR/$APP_NAME-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DIST_DIR/$APP_NAME-macOS.zip"

echo "$DIST_DIR/$APP_NAME-macOS.zip"
