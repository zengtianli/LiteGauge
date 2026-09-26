#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != '--test-only' ]; }; then
  echo 'Usage: bash build.sh [--test-only]' >&2
  exit 2
fi
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'Building and running the tests requires an Apple Silicon Mac.' >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Install Xcode Command Line Tools (xcode-select --install) or Xcode first.' >&2
  exit 1
fi
# Use the standard selected Xcode/Command Line Tools installation. An explicit
# DEVELOPER_DIR works too; no files outside this checkout are needed.
SDK="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p build
COMPILER=(xcrun swiftc -swift-version 5 -O -whole-module-optimization -target arm64-apple-macos14.0 -sdk "$SDK")
"${COMPILER[@]}" Sources/Metrics.swift Tests/main.swift -o build/tests
build/tests
if [ "${1:-}" = '--test-only' ]; then exit 0; fi
APP=build/LiteGauge.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
if [ -f icon/AppIcon.icns ]; then cp icon/AppIcon.icns "$APP/Contents/Resources/"; fi
"${COMPILER[@]}" -Xlinker -dead_strip Sources/Metrics.swift Sources/App.swift Sources/main.swift -o "$APP/Contents/MacOS/LiteGauge"
if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LiteGauge" --version
echo "Built: $PWD/$APP"
