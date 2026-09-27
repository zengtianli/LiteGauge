# Sourced by the acceptance scripts: build the current source once under a lock (acceptors run in
# parallel), then give this check its own copy. Sets APP and EXE.
LOCK=build/.accept-build.lock
mkdir -p build
for _ in $(seq 1 600); do mkdir "$LOCK" 2>/dev/null && break; sleep 0.5; done
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
bash build.sh >/dev/null 2>&1 || { echo "build or core tests failed"; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/litegauge-accept.XXXXXX")"
ditto build/LiteGauge.app "$WORK/LiteGauge.app"
rmdir "$LOCK"; trap 'rm -rf "$WORK"' EXIT
APP="$WORK/LiteGauge.app"; EXE="$APP/Contents/MacOS/LiteGauge"
