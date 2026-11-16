#!/bin/sh
# Selects the one Xcode every GitHub job of both apps builds with, so the macOS app, the iOS app
# and the shared package are always compiled by the same toolchain, and a newer Xcode appearing on
# the runner image cannot fail an unrelated pull request. The version is written here only: to move
# to a newer Xcode change XCODE_VERSION in its own pull request. Used by the macos-app, ios-app,
# ui-tests and layout-sweep workflows on the `xcode-27` runner image.
set -eu

# The Xcode the owner builds with (the macOS app needs its SDK).
XCODE_VERSION=27.2

app="/Applications/Xcode_${XCODE_VERSION}.app"
if [ ! -d "$app" ]; then
  echo "::error::Xcode ${XCODE_VERSION} is not installed on this runner (apps/scripts/select-xcode.sh)"
  ls -d /Applications/Xcode*.app
  exit 1
fi
sudo xcode-select -s "$app"
xcodebuild -version
