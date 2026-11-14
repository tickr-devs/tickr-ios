#!/bin/sh
# Build Aperture.app from the Swift package (release build, unsigned, for this Mac only).
# Usage: apps/macos/scripts/make-app.sh   -> apps/macos/build/Aperture.app
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product ApertureMac
BIN="$(swift build -c release --show-bin-path)/ApertureMac"
APP="build/Aperture.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Aperture"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Aperture</string>
  <key>CFBundleIdentifier</key><string>local.aperture.operator</string>
  <key>CFBundleExecutable</key><string>Aperture</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- The bot's API is plain HTTP on 127.0.0.1 only. -->
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST
echo "built $APP"
