#!/bin/sh
# Cold-start check for the iTerm2 launcher. Run from Terminal.app (NOT from iTerm2):
# it quits iTerm2, then asks Go2Shell to open a directory and reports window count + pwd.
set -u
APP="$(cd "$(dirname "$0")/.." && pwd)/.build/Go2Shell.app/Contents/MacOS/Go2Shell"
DIR="$HOME/tmp/go2shell-test/it's"
defaults write com.bingghost.Go2Shell terminal iTerm2
osascript -e 'tell application id "com.googlecode.iterm2" to quit' 2>/dev/null
i=0; while pgrep -x iTerm2 >/dev/null && [ $i -lt 50 ]; do sleep 0.2; i=$((i+1)); done
pgrep -x iTerm2 >/dev/null && { echo "❌ iTerm2 did not quit"; exit 1; }
"$APP" --open "$DIR" || { echo "❌ Go2Shell failed"; exit 1; }
sleep 2
N=$(osascript -e 'tell application id "com.googlecode.iterm2" to count windows')
C=$(osascript -e 'tell application id "com.googlecode.iterm2" to contents of current session of current window')
echo "iTerm2 windows after cold start: $N"
if printf '%s\n' "$C" | grep -qxF "$DIR"; then PWD_OK=1; else PWD_OK=0; fi
# iTerm may restore previous windows on launch; only the newest one is ours.
if [ "$PWD_OK" = 1 ]; then echo "✅ pwd correct ($DIR)"; else echo "❌ pwd not found in session"; fi
echo "Expected: no extra empty window besides restored ones (check visually)."
