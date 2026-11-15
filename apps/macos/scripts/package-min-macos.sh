#!/bin/sh
# Print the lowest macOS version the app supports, from Package.swift `platforms` (the one
# source; the Xcode project's MACOSX_DEPLOYMENT_TARGET must equal it, see check-deployment-target.sh).
# Usage: apps/macos/scripts/package-min-macos.sh   -> e.g. 26.0
set -eu
cd "$(dirname "$0")/.."
swift package dump-package | python3 -c '
import json, sys
found = [p["version"] for p in json.load(sys.stdin)["platforms"] if p["platformName"] == "macos"]
if len(found) != 1:
    sys.exit("package-min-macos: Package.swift must declare exactly one .macOS platform")
print(found[0])
'
