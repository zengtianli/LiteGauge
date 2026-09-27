#!/bin/bash
# native_ui acceptance: build the current source, then run the App's in-process offscreen UI self-test.
# No status item, window, focus change or synthesized input. Exit 0 = pass.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${SOP_OUT_DIR:-build/acceptance}/native-ui"
rm -rf "$OUT" && mkdir -p "$OUT"
source scripts/accept/_build.sh
set +e
RESULT="$("$EXE" --ui-self-test "$OUT")"
CODE=$?
set -e
echo "$RESULT"
python3 - "$RESULT" "$CODE" "$OUT" "$(shasum -a 256 "$EXE" | cut -d' ' -f1)" <<'PY'
import json, os, sys
result, code, out, sha = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
data = json.loads(result.strip().splitlines()[-1]) if result.strip() else {"ok": False, "checks": {}}
checks = data.get("checks", {})
failed = [k for k, v in checks.items() if not v]
summary = (f"进程内离屏界面自检 {len(checks) - len(failed)}/{len(checks)} 项通过（当前源码构建，可执行 {sha[:12]}）"
           if code == 0 and data.get("ok") else f"界面自检失败：{', '.join(failed) or '退出码 %d' % code}")
detail = {"summary": summary, "executable_sha256": sha, "built_from": "current source, ad-hoc build (scripts/accept/_build.sh)",
          "checks": checks, "screenshots": [os.path.join("perf/acceptance/native-ui", s) for s in data.get("screenshots", [])],
          "not_covered": data.get("not_covered", [])}
if os.environ.get("SOP_OUT_DIR"):
    open(os.path.join(os.environ["SOP_OUT_DIR"], "native_ui.detail.json"), "w").write(json.dumps(detail, ensure_ascii=False, indent=2) + "\n")
print(summary)
PY
exit "$CODE"
