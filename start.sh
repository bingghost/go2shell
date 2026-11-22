#!/bin/sh
# Development: build a debug bundle and run it in the foreground (Ctrl-C to quit).
# Arguments are passed to the app, e.g.
#   ./start.sh                      settings window (Finder is not frontmost when run from a terminal)
#   ./start.sh --open ~/Downloads   open the configured terminal in a folder
#   ./start.sh --print-finder-path
# Run this way, Automation permission is attributed to the terminal you run it from.
set -eu
cd "$(dirname "$0")"

BIN="$PWD/.build/dev/Go2Shell.app/Contents/MacOS/Go2Shell"

make build CONFIG=debug
# Stop a previous dev instance so the fresh build is the one on screen.
# pkill -f takes a regular expression, so escape the path (it may contain +, (, . …).
PATTERN="$(printf '%s' "$BIN" | sed 's/[][\\.*^$+?(){}|]/\\&/g')"
pkill -f "^$PATTERN" 2>/dev/null || true
exec "$BIN" "$@"
