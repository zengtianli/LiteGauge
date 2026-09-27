#!/bin/bash
# functionality acceptance: build the current source, run the core tests, and cross-check the CLI readings
# against the system counters read at the same moment. Non-interactive; starts no GUI.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/accept/_build.sh   # builds (core tests run first) and copies the app for this check
"$EXE" --version | grep -q '^LiteGauge '
"$EXE" --help | grep -q 'status'
"$EXE" status | grep -q '^CPU '
JSON="$("$EXE" status --json)"
DF="$(df -k /System/Volumes/Data | tail -1)"
MEM="$(sysctl -n hw.memsize)"; PRESS="$(sysctl -n kern.memorystatus_vm_pressure_level)"
python3 - "$JSON" "$DF" "$MEM" "$PRESS" <<'PY'
import json, os, sys
s = json.loads(sys.argv[1]); df = sys.argv[2].split(); mem = int(sys.argv[3]); press = int(sys.argv[4])
total, avail = int(df[1]) * 1024, int(df[3]) * 1024
m, d = s["memory"], s["disk"]
checks = {
    "no_errors": s["errors"] == [],
    "cpu_in_range": s["cpuPercent"] is not None and 0 <= s["cpuPercent"] <= 100,
    "memory_total_matches_hw_memsize": m["totalBytes"] == mem,
    "memory_used_within_total": 0 < m["usedBytes"] <= m["totalBytes"],
    "pressure_matches_sysctl": m["pressure"] == {1: "正常", 2: "偏高", 4: "紧张"}.get(press, "未知"),
    "disk_total_matches_df": abs(d["totalBytes"] - total) <= 1 << 20,
    "disk_available_matches_df": abs(d["availableBytes"] - avail) <= 512 << 20,
}
failed = [k for k, v in checks.items() if not v]
summary = (f"当前源码构建：14 项核心测试与 CLI 读数交叉核对 {len(checks)}/{len(checks)} 项通过" if not failed
           else "CLI 读数核对失败：" + ", ".join(failed))
out = os.environ.get("SOP_OUT_DIR")
if out:
    open(os.path.join(out, "functionality.detail.json"), "w").write(json.dumps(
        {"summary": summary, "checks": checks, "status": s, "reference": {"df_k": df, "hw_memsize": mem, "pressure_level": press}},
        ensure_ascii=False, indent=2) + "\n")
print(summary); sys.exit(1 if failed else 0)
PY
