#!/bin/bash
# Installs a built LiteGauge.app to /Applications and links ~/.local/bin/litegauge.
#
#   bash scripts/install.sh [--restart] [path/to/LiteGauge.app]
#
# First install: copies the app and adds the CLI link (an existing, different CLI entry is left alone and
# reported). Upgrade: the installed app is moved to ~/.Trash/litegauge-<old version>-<time>/ and replaced.
# LiteGauge is a resident menu-bar app. While the installed copy is running the install refuses unless
# --restart is given; then the new app's own `app quit --yes --pid` ends it (SIGTERM, same as ⌘Q), the copy
# is replaced, and it is relaunched in the background with `open -g -j` (no focus change, no synthetic
# input). If copying or verifying fails, the previous app is put back and relaunched.
set -euo pipefail
cd "$(dirname "$0")/.."
usage() { echo 'Usage: bash scripts/install.sh [--restart] [path/to/LiteGauge.app]' >&2; exit 2; }
RESTART=0
APP=''
for arg in "$@"; do
  case "$arg" in
    --restart) [ "$RESTART" = 0 ] || usage; RESTART=1 ;;
    -*) usage ;;
    *) [ -z "$APP" ] || usage; APP="$arg" ;;
  esac
done
APP="${APP:-$PWD/build/LiteGauge.app}"
DEST=/Applications/LiteGauge.app
CLI_TARGET="$DEST/Contents/MacOS/LiteGauge"
LINK="$HOME/.local/bin/litegauge"
if [ ! -x "$APP/Contents/MacOS/LiteGauge" ]; then
  echo 'App not found. Run bash build.sh first, or pass a built LiteGauge.app.' >&2
  exit 1
fi
# Check the new copy before anything running is touched.
codesign --verify --deep --strict "$APP"
NEW="$APP/Contents/MacOS/LiteGauge"

# Menu-bar instances of the installed copy, from the new build's own `app status` (offscreen self-tests and
# renderers are not listed; instances started from other bundles are not ours to stop).
installed_pids() {
  "$NEW" app status --json | DEST="$DEST" python3 -c '
import json, os, sys
for item in json.load(sys.stdin).get("instances", []):
    if item.get("bundlePath") == os.environ["DEST"]:
        print(item["pid"])'
}

WAS_RUNNING=0
PIDS=''
if [ -e "$DEST" ]; then
  PIDS="$(installed_pids)"
  if [ -n "$PIDS" ] && [ "$RESTART" != 1 ]; then
    echo "Installed LiteGauge is running (pid $(echo $PIDS)). Quit it first, or pass --restart to quit, replace and relaunch it in the background." >&2
    exit 1
  fi
fi
# A CLI entry that is not ours is reported, never replaced; checked before anything is stopped.
if { [ -e "$LINK" ] || [ -L "$LINK" ]; } && [ "$(readlink "$LINK" || true)" != "$CLI_TARGET" ]; then
  echo "Existing CLI entry; inspect it before replacing: $LINK" >&2
  exit 1
fi

for pid in $PIDS; do
  if ! "$NEW" app quit --yes --pid "$pid"; then
    echo 'Waiting for the active background service to finish restoring before upgrade…'
    for _ in $(seq 120); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo 'Background restoration is still running; upgrade stopped without forcing exit.' >&2
      exit 1
    fi
  fi
  WAS_RUNNING=1
done

relaunch() {
  [ "$WAS_RUNNING" = 1 ] || return 0
  open -g -j -a "$DEST"
  for _ in $(seq 100); do
    pid="$(installed_pids | head -1)"
    if [ -n "$pid" ]; then echo "Relaunched in the background: pid $pid"; return 0; fi
    sleep 0.1
  done
  echo 'LiteGauge did not come back within 10 s; start it from /Applications.' >&2
  return 1
}

BACKUP=''
restore() {
  echo 'Install failed; putting the previous app back.' >&2
  rm -rf "$DEST"
  if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then mv "$BACKUP" "$DEST"; fi
  relaunch || true
}

if [ -e "$DEST" ]; then
  OLD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
  SHELF="$HOME/.Trash/litegauge-$OLD_VERSION-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$SHELF"
  BACKUP="$SHELF/LiteGauge.app"
  mv "$DEST" "$BACKUP"
fi
trap restore ERR
ditto "$APP" "$DEST"
codesign --verify --deep --strict "$DEST"
trap - ERR
if [ ! -L "$LINK" ]; then
  mkdir -p "$(dirname "$LINK")"
  ln -s "$CLI_TARGET" "$LINK"
fi
# Optional keyboard catalog integration; it is not an app dependency.
KEYS_DIR="$HOME/.config/mackit/keys.d"
if [ -d "$KEYS_DIR" ] && [ -f keys.json ] && [ ! -e "$KEYS_DIR/litegauge.json" ] && [ ! -L "$KEYS_DIR/litegauge.json" ]; then
  ln -s "$PWD/keys.json" "$KEYS_DIR/litegauge.json"
fi
echo "Installed: $DEST ($("$CLI_TARGET" --version))"
[ -z "$BACKUP" ] || echo "Previous app moved to: $BACKUP"
echo "CLI: $LINK -> $CLI_TARGET (add ~/.local/bin to PATH if needed)"
relaunch
