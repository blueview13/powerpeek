#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/build/PowerPeek.app"
DMG_PATH="$ROOT_DIR/build/PowerPeek.dmg"
STAGING_DIR="$ROOT_DIR/build/dmg-staging"

"$ROOT_DIR/Scripts/build-app.sh"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "PowerPeek" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING_DIR"
printf '%s\n' "Built $DMG_PATH"
