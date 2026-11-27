#!/bin/sh
# Fail unless the app binary answers the bot's notify mode (`<binary> --notify-alert TITLE TEXT`,
# src/tickr/runtime/alerts.py AppNotifier) by exiting on its own, with one of its notify-mode
# codes (AlertExit: 0 shown, 2 not allowed, 3 failed), instead of starting the app. A binary that
# opens its window never exits and is stopped after LIMIT seconds. CI has no notification
# permission, so it answers 2 there; on the owner's Mac it answers 0.
# Usage: apps/macos/scripts/check-notify-mode.sh path/to/Tickr.app/Contents/MacOS/<binary>
set -u
BIN="${1:?usage: check-notify-mode.sh path/to/binary}"
# Seconds the notify mode may take; Notification Center answers in well under one.
LIMIT=60
perl -e 'alarm shift; exec @ARGV or exit 127' "$LIMIT" "$BIN" --notify-alert "Tickr CI" "notify mode check"
code=$?
case "$code" in
  0|2|3) echo "check-notify-mode: $BIN exited $code in notify mode" ;;
  142) echo "check-notify-mode: $BIN still running after ${LIMIT}s: it started the app" >&2; exit 1 ;;
  *) echo "check-notify-mode: $BIN exited $code, not a notify-mode code" >&2; exit 1 ;;
esac
