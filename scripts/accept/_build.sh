# Sourced by the acceptance scripts: compile/test unchanged inputs once under a lock,
# verify the complete output bytes before reuse, then give each check its own copy.
LOCK=build/.accept-build.lock
mkdir -p build
ACQUIRED=0
for _ in $(seq 1 600); do
  if mkdir "$LOCK" 2>/dev/null; then ACQUIRED=1; break; fi
  sleep 0.5
done
if [ "$ACQUIRED" != 1 ]; then
  echo 'Acceptance build lock busy; preserved the existing owner and outputs.' >&2
  exit 75
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
BUILD_KEY="$(python3 scripts/accept/build_cache.py key)"
if python3 scripts/accept/build_cache.py check "$BUILD_KEY"; then
  echo "Reusing verified current-source build: $BUILD_KEY"
else
  bash build.sh >build/accept-build.log 2>&1 || { cat build/accept-build.log; exit 1; }
  python3 scripts/accept/build_cache.py save "$BUILD_KEY"
  cat build/accept-build.log
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/litegauge-accept.XXXXXX")"
ditto build/LiteGauge.app "$WORK/LiteGauge.app"
rmdir "$LOCK"; trap 'rm -rf "$WORK"' EXIT
APP="$WORK/LiteGauge.app"; EXE="$APP/Contents/MacOS/LiteGauge"
