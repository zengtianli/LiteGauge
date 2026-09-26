#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/LiteGauge.app"
if [ ! -x "$APP/Contents/MacOS/LiteGauge" ]; then
  echo '先运行 bash build.sh' >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
if [ -e /Applications/LiteGauge.app ]; then
  echo '已有安装版；请核对运行实例并可回溯归档旧版后再安装。' >&2
  exit 1
fi
for target in "$HOME/.local/bin/litegauge" "$HOME/.config/mackit/keys.d/litegauge.json"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "安装入口已存在，请先核对：$target" >&2
    exit 1
  fi
done
ditto "$APP" /Applications/LiteGauge.app
mkdir -p "$HOME/.local/bin" "$HOME/.config/mackit/keys.d"
ln -s /Applications/LiteGauge.app/Contents/MacOS/LiteGauge "$HOME/.local/bin/litegauge"
ln -s "$PWD/keys.json" "$HOME/.config/mackit/keys.d/litegauge.json"
codesign --verify --deep --strict /Applications/LiteGauge.app
echo 'Installed: /Applications/LiteGauge.app'
