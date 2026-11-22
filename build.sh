#!/bin/sh
# Build, bundle and sign the release app at .build/Go2Shell.app.
# UNIVERSAL=1 ./build.sh builds arm64 + x86_64; SIGN_ID=... overrides the signing identity.
set -eu
cd "$(dirname "$0")"

make build CONFIG=release
