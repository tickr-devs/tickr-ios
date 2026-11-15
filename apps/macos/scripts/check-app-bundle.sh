#!/bin/sh
# Fail unless a built Tickr.app carries its app icon: Info.plist CFBundleIconFile and
# CFBundleIconName set, Contents/Resources/<CFBundleIconFile>.icns present, and Assets.car
# present with an icon entry named CFBundleIconName (what Finder and the Dock look up).
# Usage: apps/macos/scripts/check-app-bundle.sh apps/macos/build/Tickr.app
set -eu
APP="${1:?usage: check-app-bundle.sh path/to/Tickr.app}"
PLIST="$APP/Contents/Info.plist"
RES="$APP/Contents/Resources"
fail() { echo "check-app-bundle: $*" >&2; exit 1; }
[ -f "$PLIST" ] || fail "no Info.plist in $APP"
ICON_FILE="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$PLIST" 2>/dev/null)" \
  || fail "Info.plist has no CFBundleIconFile"
ICON_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$PLIST" 2>/dev/null)" \
  || fail "Info.plist has no CFBundleIconName"
# CFBundleIconFile may be given with or without its .icns extension.
case "$ICON_FILE" in *.icns) ICNS="$RES/$ICON_FILE" ;; *) ICNS="$RES/$ICON_FILE.icns" ;; esac
[ -s "$ICNS" ] || fail "CFBundleIconFile '$ICON_FILE' does not resolve: no $ICNS"
[ -s "$RES/Assets.car" ] || fail "no Assets.car in $RES"
xcrun assetutil --info "$RES/Assets.car" | grep -q "\"Name\" : \"$ICON_NAME\"" \
  || fail "CFBundleIconName '$ICON_NAME' does not resolve: no such entry in Assets.car"
echo "check-app-bundle: $APP has icon $ICON_NAME (Assets.car, $(basename "$ICNS"))"
