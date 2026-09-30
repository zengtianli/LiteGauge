#!/bin/bash
# functionality acceptance: build the current source, run the core tests, and cross-check the CLI readings
# (status, watch, app status, help, short-name usage) against the system counters read at the same moment.
# Non-interactive; starts no GUI and never signals the running App.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/accept/_build.sh   # builds (core tests run first) and copies the app for this check
"$EXE" --version | grep -q '^LiteGauge '
for h in --help -h help "status --help" "watch --help" "app --help"; do "$EXE" $h | grep -q 'litegauge watch'; done
# --help after the dev flags that --help lists shows help and runs nothing (run in $WORK so a regression cannot litter the repo).
# --benchmark --help is covered by the core tests only: a regression there would start a GUI instance.
for h in "--snapshot -h" "--ui-self-test --help" "--background --help"; do (cd "$WORK" && "$EXE" $h </dev/null) | grep -q 'litegauge watch'; done
"$EXE" status | grep -q '^CPU '
ln -s "$EXE" "$WORK/litegauge"   # the short command name must print usage, never start the menu-bar App
set +e; SHORT_OUT="$("$WORK/litegauge" </dev/null 2>/dev/null)"; SHORT_CODE=$?; set -e
JSON="$("$EXE" status --json)"
DF="$(df -k /System/Volumes/Data | tail -1)"
MEM="$(sysctl -n hw.memsize)"; PRESS="$(sysctl -n kern.memorystatus_vm_pressure_level)"
WATCH="$("$EXE" watch --interval 1 --count 2 --json)"
# Menu-bar instances outside this acceptance run's temporary copies (other acceptors may start test instances from theirs).
APPS="$("$EXE" app status --json)"; PIDS="$(ps -axo pid=,comm= | awk '$2 ~ /\/LiteGauge$/ && $2 !~ /litegauge-accept/ {print $1}' | tr '\n' ' ')"
python3 - "$JSON" "$DF" "$MEM" "$PRESS" "$WATCH" "$APPS" "$PIDS" "$SHORT_CODE:${#SHORT_OUT}" <<'PY'
import json, os, sys
s = json.loads(sys.argv[1]); df = sys.argv[2].split(); mem = int(sys.argv[3]); press = int(sys.argv[4])
watch = [json.loads(line) for line in sys.argv[5].splitlines()]; apps = json.loads(sys.argv[6])
pids = sorted(int(p) for p in sys.argv[7].split()); short = sys.argv[8]
total, avail = int(df[1]) * 1024, int(df[3]) * 1024
m, d = s["memory"], s["disk"]
level = {1: "normal", 2: "elevated", 4: "critical"}.get(press, "unknown")
checks = {
    "no_errors": s["errors"] == [],
    "cpu_in_range": s["cpuPercent"] is not None and 0 <= s["cpuPercent"] <= 100,
    "memory_total_matches_hw_memsize": m["totalBytes"] == mem,
    "memory_used_within_total": 0 < m["usedBytes"] <= m["totalBytes"],
    "pressure_matches_sysctl": m["pressure"] == {1: "正常", 2: "偏高", 4: "紧张"}.get(press, "未知"),
    "disk_total_matches_df": abs(d["totalBytes"] - total) <= 1 << 20,
    "disk_available_matches_df": abs(d["availableBytes"] - avail) <= 512 << 20,
    "ok_and_error_codes": s["ok"] is True and s["errorCodes"] == [],
    "pressure_level_matches_sysctl": m["pressureLevel"] == level,
    "memory_percent_and_level": abs(m["percent"] - m["usedBytes"] / m["totalBytes"] * 100) < 1e-6
        and m["level"] == {"critical": "critical", "elevated": "warning"}.get(level, "normal"),
    "disk_used_percent_and_level": abs(d["usedPercent"] - 100 * (1 - d["availableBytes"] / d["totalBytes"])) < 1e-6
        and d["level"] == ("warning" if d["usedPercent"] > d["warnAbovePercent"] else "normal") and d["warnAbovePercent"] == 90,
    "watch_two_ndjson_records": len(watch) == 2 and all(r["ok"] and r["cpuPercent"] is not None for r in watch)
        and watch[0]["disk"]["sampledAt"] == watch[1]["disk"]["sampledAt"],
    "app_status_matches_ps": apps["ok"] and apps["running"] == bool(pids)
        and sorted(i["pid"] for i in apps["instances"] if "litegauge-accept" not in (i["executablePath"] or "")) == pids,
    "short_name_prints_usage_only": short == "2:0",
}
failed = [k for k, v in checks.items() if not v]
summary = (f"当前源码构建：核心测试通过，CLI 读数与命令交叉核对 {len(checks)}/{len(checks)} 项通过" if not failed
           else "CLI 读数核对失败：" + ", ".join(failed))
out = os.environ.get("SOP_OUT_DIR")
if out:
    open(os.path.join(out, "functionality.detail.json"), "w").write(json.dumps(
        {"summary": summary, "checks": checks, "status": s, "watch": watch, "app_status": {"running": apps["running"], "instances": len(apps["instances"])},
         "reference": {"df_k": df, "hw_memsize": mem, "pressure_level": press}},
        ensure_ascii=False, indent=2) + "\n")
print(summary); sys.exit(1 if failed else 0)
PY
