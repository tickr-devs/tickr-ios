#!/bin/sh
# Build Tickr.app from the Swift package (release build, unsigned, for this Mac only).
# Usage: apps/macos/scripts/make-app.sh   -> apps/macos/build/Tickr.app
set -eu
cd "$(dirname "$0")/.."
# Lowest macOS the app runs on, read from its one source: Package.swift `platforms`
# (scripts/check-deployment-target.sh keeps the Xcode project's MACOSX_DEPLOYMENT_TARGET equal).
# Used for the icon compile and LSMinimumSystemVersion.
MIN_MACOS="$(scripts/package-min-macos.sh)"
# App icon name: the Xcode project's ASSETCATALOG_COMPILER_APPICON_NAME (the AppIcon.icon file).
ICON_NAME=AppIcon
swift build -c release --product TickrMac
BIN="$(swift build -c release --show-bin-path)/TickrMac"
APP="build/Tickr.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Tickr"
# The String Catalogs (app and shared package) are compiled into SwiftPM resource bundles.
mkdir -p "$APP/Contents/Resources"
cp -R "$(swift build -c release --show-bin-path)"/*.bundle "$APP/Contents/Resources/"
# App icon: compiled from the Icon Composer file the same way Xcode does (actool), into
# Assets.car and AppIcon.icns; actool also writes the Info.plist icon keys it expects.
ICON_KEYS="$(mktemp -d)/icon-keys.plist"
xcrun actool "Tickr/$ICON_NAME.icon" --compile "$APP/Contents/Resources" \
  --app-icon "$ICON_NAME" --output-partial-info-plist "$ICON_KEYS" \
  --platform macosx --target-device mac --minimum-deployment-target "$MIN_MACOS" \
  --development-region en --output-format human-readable-text --errors --warnings >/dev/null
# Info.plist: the keys the Xcode target shares (Support/Info.plist: name, languages, local HTTP,
# alert style), plus the ones Xcode generates from build settings. One source for both builds.
PLIST="$APP/Contents/Info.plist"
plutil -convert xml1 -o "$PLIST" Support/Info.plist
# Bundle id: the prefix from its one source (apps/Config/Identity.xcconfig) plus the Mac suffix,
# as the Xcode target builds it.
PREFIX="$(sed -n 's/^TICKR_BUNDLE_ID_PREFIX = //p' ../Config/Identity.xcconfig)"
[ -n "$PREFIX" ] || { echo "make-app.sh: TICKR_BUNDLE_ID_PREFIX missing in apps/Config/Identity.xcconfig" >&2; exit 1; }
plutil -insert CFBundleIdentifier -string "$PREFIX.mac" "$PLIST"
plutil -insert CFBundleExecutable -string Tickr "$PLIST"
plutil -insert CFBundlePackageType -string APPL "$PLIST"
plutil -insert CFBundleShortVersionString -string 0.1 "$PLIST"
plutil -insert LSMinimumSystemVersion -string "$MIN_MACOS" "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"
# CFBundleIconFile and CFBundleIconName from the icon compile above.
/usr/libexec/PlistBuddy -c "Merge $ICON_KEYS" "$PLIST" >/dev/null
rm -rf "$(dirname "$ICON_KEYS")"
echo "built $APP"
