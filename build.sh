#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source /Users/tianli/Dev/tools/dev/lib/tools/macapp/xcode_env.sh
xcode_env_use macosx
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
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LiteGauge" --version
echo "Built: $PWD/$APP"
