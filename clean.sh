#!/bin/sh
# Remove all build products (debug and release bundles, SwiftPM build output).
# Fetched third-party dependencies are kept.
set -eu
cd "$(dirname "$0")"

make clean
