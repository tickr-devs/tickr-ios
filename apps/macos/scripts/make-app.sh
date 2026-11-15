#!/bin/sh
# Build Tickr.app from the Swift package (release build, unsigned, for this Mac only).
# Usage: apps/macos/scripts/make-app.sh   -> apps/macos/build/Tickr.app
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product TickrMac
BIN="$(swift build -c release --show-bin-path)/TickrMac"
APP="build/Tickr.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Tickr"
# The String Catalogs (app and shared package) are compiled into SwiftPM resource bundles.
mkdir -p "$APP/Contents/Resources"
cp -R "$(swift build -c release --show-bin-path)"/*.bundle "$APP/Contents/Resources/"
# Info.plist: the keys the Xcode target shares (Support/Info.plist: name, languages, local HTTP,
# alert style), plus the ones Xcode generates from build settings. One source for both builds.
PLIST="$APP/Contents/Info.plist"
plutil -convert xml1 -o "$PLIST" Support/Info.plist
plutil -insert CFBundleIdentifier -string local.tickr.operator "$PLIST"
plutil -insert CFBundleExecutable -string Tickr "$PLIST"
plutil -insert CFBundlePackageType -string APPL "$PLIST"
plutil -insert CFBundleShortVersionString -string 0.1 "$PLIST"
plutil -insert LSMinimumSystemVersion -string 14.0 "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"
echo "built $APP"
