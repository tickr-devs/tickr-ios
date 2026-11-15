#!/bin/sh
# Fail unless every MACOSX_DEPLOYMENT_TARGET in the Xcode project equals the macOS version in
# Package.swift `platforms` (the one source), so both builds target the same macOS.
# Usage: apps/macos/scripts/check-deployment-target.sh
set -eu
cd "$(dirname "$0")/.."
WANT="$(scripts/package-min-macos.sh)"
PBX=TickrMac.xcodeproj/project.pbxproj
FOUND="$(sed -n 's/.*MACOSX_DEPLOYMENT_TARGET = \([^;]*\);.*/\1/p' "$PBX" | sort -u)"
[ -n "$FOUND" ] || { echo "check-deployment-target: no MACOSX_DEPLOYMENT_TARGET in $PBX" >&2; exit 1; }
[ "$FOUND" = "$WANT" ] || {
  echo "check-deployment-target: $PBX MACOSX_DEPLOYMENT_TARGET ($(echo $FOUND)) != Package.swift macOS $WANT" >&2
  exit 1
}
echo "check-deployment-target: Xcode project and Package.swift both target macOS $WANT"
