#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -gt 1 ]; then
  echo 'Usage: bash scripts/install.sh [path/to/LiteGauge.app]' >&2
  exit 2
fi
APP="${1:-$PWD/build/LiteGauge.app}"
if [ ! -x "$APP/Contents/MacOS/LiteGauge" ]; then
  echo 'App not found. Run bash build.sh first, or pass a built LiteGauge.app.' >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
if [ -e /Applications/LiteGauge.app ]; then
  echo 'LiteGauge is already installed. Quit it and use Finder to replace the existing app.' >&2
  exit 1
fi
for target in "$HOME/.local/bin/litegauge"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Existing CLI entry; inspect it before replacing: $target" >&2
    exit 1
  fi
done
ditto "$APP" /Applications/LiteGauge.app
mkdir -p "$HOME/.local/bin"
ln -s /Applications/LiteGauge.app/Contents/MacOS/LiteGauge "$HOME/.local/bin/litegauge"
# Optional keyboard catalog integration; it is not an app dependency.
KEYS_DIR="$HOME/.config/mackit/keys.d"
if [ -d "$KEYS_DIR" ] && [ -f keys.json ] && [ ! -e "$KEYS_DIR/litegauge.json" ] && [ ! -L "$KEYS_DIR/litegauge.json" ]; then
  ln -s "$PWD/keys.json" "$KEYS_DIR/litegauge.json"
fi
codesign --verify --deep --strict /Applications/LiteGauge.app
echo 'Installed: /Applications/LiteGauge.app'
echo 'CLI: ~/.local/bin/litegauge (add ~/.local/bin to PATH if needed)'
