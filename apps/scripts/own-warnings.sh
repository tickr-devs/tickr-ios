#!/bin/sh
# Fails when an xcodebuild log holds a Swift compiler warning in this repository's own code (not
# in a package dependency under SourcePackages or .build). Xcode on the owner's Mac reported
# warnings the CI build only printed as errors (2026-11-26: main-actor-isolated static lets read
# from nonisolated code), so the app jobs treat our own warnings as failures. Usage: own-warnings.sh LOG
set -eu

log="$1"
found=$(grep -E '\.swift:[0-9]+:[0-9]+: warning:' "$log" | grep -v -E '/SourcePackages/|/\.build/checkouts/' | sort -u || true)
if [ -n "$found" ]; then
  echo "::error::Swift compiler warnings in our own code (fix them; the owner's Xcode stops on them):"
  echo "$found"
  exit 1
fi
