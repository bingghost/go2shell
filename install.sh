#!/bin/sh
# Build the release app, install it to /Applications, open it, then remove all build products.
set -eu
cd "$(dirname "$0")"

./build.sh
# Quit any running copy (installed or dev) before its bundle is replaced.
pkill -x Go2Shell 2>/dev/null || true
make deploy
open /Applications/Go2Shell.app
./clean.sh
