#!/bin/sh
# Layout sweep of the macOS app (Tickr/Previews/LayoutSweep.swift): every screen at several
# window sizes, Chart inspector closed and open, in English and Russian, on the fixture data.
# Fails when the app crashes or hangs (for example AppKit's "Update Constraints in Window" loop
# while the window is resized), and when a picture shows a truncated text (a text ending in an
# ellipsis the String Catalogs do not have: apps/scripts/find_truncated_text.swift).
# Needs a logged-in macOS session; no Screen Recording permission.
# Usage: apps/macos/scripts/layout-sweep.sh [output folder, default build/layout-sweep]
#   -> <folder>/<language>/<width>x<height>-<section>[-inspector].png
set -eu
cd "$(dirname "$0")/.."
OUT="${1:-build/layout-sweep}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
# Seconds one language may take before the run counts as hung.
LIMIT=420
swift build --product TickrMac
# A bare executable has no bundle that declares Russian, so macOS would show it in English
# whatever -AppleLanguages says. Wrap the debug build in a minimal app that declares both
# languages, with its own bundle id, so its settings never touch the real app's.
# The String Catalogs are SwiftPM resource bundles, copied into the app's Resources.
APP="build/LayoutSweep.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build --show-bin-path)/TickrMac" "$APP/Contents/MacOS/TickrMac"
mkdir -p "$APP/Contents/Resources"
cp -R "$(swift build --show-bin-path)"/*.bundle "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Tickr</string>
  <key>CFBundleIdentifier</key><string>local.tickr.layoutsweep</string>
  <key>CFBundleExecutable</key><string>TickrMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
BIN="$APP/Contents/MacOS/TickrMac"
status=0
for lang in en ru; do
  rm -rf "${OUT:?}/$lang"
  mkdir -p "$OUT/$lang"
  TICKR_FIXTURES=1 TICKR_LAYOUT_SWEEP="$OUT/$lang" \
    "$BIN" -AppleLanguages "($lang)" -AppleLocale "${lang}_US" -ApplePersistenceIgnoreState YES \
    -appearance dark > "$OUT/$lang.log" 2>&1 &
  pid=$!
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$LIMIT" ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" || true
    echo "::error::layout sweep ($lang) hung for ${LIMIT}s"
    status=1
    continue
  fi
  if wait "$pid" && [ -f "$OUT/$lang/done" ]; then
    echo "layout sweep ($lang): $(ls "$OUT/$lang"/*.png | wc -l | tr -d ' ') pictures"
    # Sizes under the window's least size (TickrMacApp.minWidth) are left out, not faked.
    if [ -f "$OUT/$lang/skipped-sizes.txt" ]; then
      echo "layout sweep ($lang): left out, smaller than the window's least size:"
      cat "$OUT/$lang/skipped-sizes.txt"; echo
    fi
  else
    echo "::error::layout sweep ($lang) crashed; last log lines:"
    tail -n 40 "$OUT/$lang.log"
    status=1
  fi
done
# No text may be cut (owner rule 2026-11-16): read every picture for an ellipsis.
if ! swift ../scripts/find_truncated_text.swift "$OUT"; then
  echo "::error::layout sweep: truncated text (listed above)"
  status=1
fi
exit "$status"
