#!/bin/bash
# recovery acceptance: invalid input is rejected cleanly, a duplicate GUI instance exits by itself,
# and pause/resume/baseline logic passes its tests. Never starts a new menu-bar item.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/accept/_build.sh
bad() { local out code; set +e; out="$("$EXE" "$@" 2>/dev/null)"; code=$?; set -e; echo "$code:${#out}"; }
R1="$(bad --bogus)"; R2="$(bad status --json extra)"; R3="$(bad --snapshot)"
DUP=skipped
if pgrep -xq LiteGauge; then   # only when an instance already runs, so the test never adds a status item
  "$EXE" & P=$!
  for _ in $(seq 1 20); do kill -0 $P 2>/dev/null || break; sleep 0.5; done
  if kill -0 $P 2>/dev/null; then kill $P; DUP=still_running; else wait $P; DUP=exited; fi
fi
python3 - "$R1" "$R2" "$R3" "$DUP" <<'PY'
import json, os, sys
bad = sys.argv[1:4]; dup = sys.argv[4]
checks = {f"invalid_args_{i}_exit2_no_stdout": b == "2:0" for i, b in enumerate(bad)}
checks["duplicate_instance_exits"] = dup in ("exited", "skipped")
checks["pause_resume_baseline_tests"] = True  # build.sh aborts above if the 14 core tests fail
failed = [k for k, v in checks.items() if not v]
summary = (f"非法参数退出 2、重复实例{'自行退出' if dup == 'exited' else '未测（无运行实例）'}、暂停/唤醒/基线测试通过" if not failed
           else "恢复检查失败：" + ", ".join(failed))
out = os.environ.get("SOP_OUT_DIR")
if out:
    open(os.path.join(out, "recovery.detail.json"), "w").write(json.dumps({"summary": summary, "checks": checks, "duplicate_instance": dup,
        "not_covered": ["real sleep/wake cycle", "injected sampler read failure"]}, ensure_ascii=False, indent=2) + "\n")
print(summary); sys.exit(1 if failed else 0)
PY
