#!/bin/bash
# native_ui acceptance: build the current source, then run the App's in-process offscreen UI self-test.
# No status item, window, focus change or synthesized input. Exit 0 = pass.
set -euo pipefail
cd "$(dirname "$0")/../.."
BASE="${SOP_OUT_DIR:-$PWD/build/acceptance}"
mkdir -p "$BASE"
OUT="$(mktemp -d "$BASE/native-ui.XXXXXX")"
source scripts/accept/_build.sh
set +e
RESULT="$("$EXE" --ui-self-test "$OUT")"
CODE=$?
set -e
echo "$RESULT"
python3 - "$RESULT" "$CODE" "$OUT" "$(shasum -a 256 "$EXE" | cut -d' ' -f1)" <<'PY'
import json, os, struct, sys
from pathlib import Path
result, code, out, sha = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
data = json.loads(result.strip().splitlines()[-1]) if result.strip() else {"ok": False, "checks": {}}
checks = data.get("checks", {})
screenshots = [Path(out) / s for s in data.get("screenshots", [])]
def valid_png(path):
    try:
        header = path.read_bytes()[:24]
        return len(header) == 24 and header[:8] == b'\x89PNG\r\n\x1a\n' and all(struct.unpack('>II', header[16:24]))
    except OSError:
        return False
checks["screenshots_written_and_nonempty"] = bool(screenshots) and all(valid_png(p) for p in screenshots)
failed = [k for k, v in checks.items() if not v]
passed = code == 0 and data.get("ok") and not failed
summary = (f"进程内离屏界面自检 {len(checks) - len(failed)}/{len(checks)} 项通过（当前源码构建，可执行 {sha[:12]}）"
           if passed else f"界面自检失败：{', '.join(failed) or '退出码 %d' % code}")
detail = {"summary": summary, "executable_sha256": sha, "built_from": "current source, ad-hoc build (scripts/accept/_build.sh)",
          "checks": checks, "screenshots": [os.path.relpath(os.path.join(out, s)) for s in data.get("screenshots", [])],
          "not_covered": data.get("not_covered", [])}
if os.environ.get("SOP_OUT_DIR"):
    open(os.path.join(os.environ["SOP_OUT_DIR"], "native_ui.detail.json"), "w").write(json.dumps(detail, ensure_ascii=False, indent=2) + "\n")
print(summary)
sys.exit(0 if passed else 1)
PY
exit "$CODE"
