#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="PowerPeek"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE="$ROOT_DIR/.build/release/$APP_NAME"

cd "$ROOT_DIR"
swift build -c release
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_NAME"

ICONSET_DIR="$BUILD_DIR/PowerPeek.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
swiftc "$ROOT_DIR/Scripts/generate-icon.swift" -o "$BUILD_DIR/generate-icon"
"$BUILD_DIR/generate-icon" "$ICONSET_DIR"
rm -f "$BUILD_DIR/generate-icon"
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/PowerPeek.icns"
rm -rf "$ICONSET_DIR"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>PowerPeek</string>
    <key>CFBundleExecutable</key>
    <string>PowerPeek</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.PowerPeek</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>BatteryBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>PowerPeek</string>
</dict>
</plist>
PLIST

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
printf '%s\n' "Built $APP_DIR"
