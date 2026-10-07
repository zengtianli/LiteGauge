#!/bin/bash
# Lifecycle check: the App's own offscreen self-test (`--lifecycle-self-test`). The process under test is the running
# App (the production wiring, no status item, no visible window, no Dock icon); the real `litegauge config …`
# commands are run against it. It checks that the App follows `config sync on|off` and `config import`, and that the
# stored switch is never written back, including two commands back to back.
#
#   bash scripts/accept/lifecycle.sh [path/to/LiteGauge.app] [output dir]
#
# It never builds: it checks the app it is given (default build/LiteGauge.app), so a signed build waiting to be
# installed is not replaced. Policy, switch and "cloud" folder are throwaway; the owner's policy, preferences and
# iCloud Drive are not touched, and no network is used. Exit 0 = pass.
set -euo pipefail
cd "$(dirname "$0")/../.."
APP="${1:-$PWD/build/LiteGauge.app}"
OUT="${2:-${SOP_OUT_DIR:-build/acceptance}/lifecycle}"
EXE="$APP/Contents/MacOS/LiteGauge"
[ -x "$EXE" ] || { echo "App not found: $APP (run bash build.sh first, or pass a built LiteGauge.app)" >&2; exit 1; }
mkdir -p "$OUT"
set +e
RESULT="$("$EXE" --lifecycle-self-test "$OUT")"
CODE=$?
set -e
echo "$RESULT"
# The run's throwaway preference domain: the preferences daemon writes its empty shell after the test process has
# exited, so it is removed here. Only a domain with the test prefix is ever deleted.
DOMAIN="$(python3 -c '
import json, sys
lines = sys.argv[1].strip().splitlines()
try: print(json.loads(lines[-1]).get("preference_domain", "") if lines else "")
except ValueError: print("")' "$RESULT")"
case "$DOMAIN" in
  test.tianli.litegauge.*)
    defaults delete "$DOMAIN" >/dev/null 2>&1 || true
    SHELL_FILE="$HOME/Library/Preferences/$DOMAIN.plist"
    for _ in $(seq 20); do
      if [ -f "$SHELL_FILE" ] && [ "$(stat -f %z "$SHELL_FILE")" -le 42 ]; then rm -f -- "$SHELL_FILE"; fi
      sleep 0.5
    done
    ;;
esac
python3 - "$RESULT" "$CODE" "$(shasum -a 256 "$EXE" | cut -d' ' -f1)" <<'PY'
import json, sys
result, code, sha = sys.argv[1], int(sys.argv[2]), sys.argv[3]
lines = result.strip().splitlines()
try:
    data = json.loads(lines[-1]) if lines else {}
except ValueError:
    data = {}
failed = data.get("failed", [])
if code == 0 and data.get("ok"):
    print(f"生命周期离屏自检 {data.get('count')} 项通过：命令拨开关、导入后 App 跟随，存储值未被写回"
          f"（背靠背回退 {len(data.get('back_to_back_regressions', []))} 次，共跑命令 {data.get('commands_run')} 条；可执行 {sha[:12]}）")
else:
    print("生命周期自检失败：" + (", ".join(failed) or f"退出码 {code}"))
PY
exit "$CODE"
