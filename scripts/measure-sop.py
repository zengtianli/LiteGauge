#!/usr/bin/env python3
"""Chapter's registered re-measurement for LiteGauge (project.yaml sop.measure.command).

LiteGauge is a resident menu-bar app without a main window. Sampling only the running instance records idle numbers
and sizes, so every new version lost its headline speed (0.1.2 (3): speed missing after Chapter's passive re-measure).
This script measures the installed build that release/latest.json names and writes perf/lightweight.json and perf/raw/:

  idle + size  the shared app-lightweight batch_measure on the long-running instance (passive, 60 s, helpers included)
               plus the release zip (sop-equivalent download: build/release/LiteGauge-{short}-arm64.zip)
  speed        5 test instances `open -g -j -n LiteGauge.app --args --benchmark <file>`: each writes ready_ms (AppDelegate
               setup to the first valid CPU reading, includes the 1 s sampling window; not a full cold start) and is then
               ended by the pid it wrote, after checking that pid runs --benchmark; the owner's instance is never touched

A test instance briefly adds a second menu-bar item (never a window, never focus), so this runs only while the owner
is away (sop.measure.in_use: false; app_sop's gate). Exits 75 (DEFER_EXIT) when the machine is not steady or the
owner came back while it ran; nothing is written then. Not a build input of the installed-app receipt.
"""
import json
import os
import plistlib
import re
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = Path("/Applications/LiteGauge.app")
EXE = APP / "Contents/MacOS/LiteGauge"
DOWNLOAD = "build/release/LiteGauge-{short}-arm64.zip"
LW = Path.home() / "Apps/.claude/skills/app-lightweight/scripts"
DEFER = 75
RUNS = 5
sys.path.insert(0, str(Path.home() / "Apps/chapter/engine"))
sys.path.insert(0, str(LW))
import app_sop  # noqa: E402
import batch_measure  # noqa: E402


def write_json(path, value):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    tmp.replace(path)


def end_test_instance(pid, marker):
    """SIGTERM only a process whose command line is this run's --benchmark instance."""
    command = subprocess.run(["ps", "-o", "command=", "-p", str(pid)], capture_output=True, text=True).stdout
    if "--benchmark" not in command or marker not in command:
        raise RuntimeError(f"pid {pid} 不是本次 --benchmark 测试实例，不结束它")
    os.kill(pid, signal.SIGTERM)
    for _ in range(50):
        if subprocess.run(["kill", "-0", str(pid)], capture_output=True).returncode:
            return
        time.sleep(0.1)
    os.kill(pid, signal.SIGKILL)


def benchmark_runs(workdir):
    samples = []
    for i in range(RUNS):
        out = workdir / f"benchmark-{i}.json"
        subprocess.run(["open", "-g", "-j", "-n", str(APP), "--args", "--benchmark", str(out)], check=True)
        deadline = time.monotonic() + 20
        while not out.is_file() and time.monotonic() < deadline:
            time.sleep(0.1)
        if not out.is_file():
            stray = [p for p in batch_measure.sh("pgrep", "-f", re.escape(str(out))).split() if p]
            for pid in stray:
                end_test_instance(int(pid), str(out))
            raise RuntimeError("测试实例 20 秒内没有写出首个 CPU 读数")
        data = json.loads(out.read_text())
        end_test_instance(int(data["pid"]), str(out))
        samples.append(round(float(data["ready_ms"]), 1))
        time.sleep(2)
    return samples


def main():
    in_use = os.environ.get(app_sop.SAMPLE_GATE_ENV) == "1"
    steady, why = app_sop.steady()
    if not steady:
        print(f"未测量：{why}")
        return DEFER
    release = json.loads((ROOT / "release/latest.json").read_text())
    info = plistlib.loads((APP / "Contents/Info.plist").read_bytes())
    short, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    if (str(release.get("version")), str(release.get("build"))) != (short, build):
        print(f"装机 {short} ({build}) 不是 release/latest.json 记录的发行构建 {release.get('version')} ({release.get('build')})")
        return 1
    running = [p for p in batch_measure.sh("pgrep", "-f", re.escape(str(EXE))).split() if p]
    if len(running) != 1:
        print(f"常驻实例需要恰好一个，实际 PID={running}；按 scripts/install.sh 恢复常驻后再测")
        return 1

    # 1. Idle, installed size and the release zip from the long-running instance (shared batch_measure publishes it).
    spec = {"app": str(APP), "running": str(EXE), "launch": False, "download": DOWNLOAD, "repo": ROOT, "in_use": in_use}
    try:
        batch_measure.run("litegauge", spec)
    except batch_measure.Deferred as exc:
        print(exc)
        return DEFER

    # 2. Headline speed from separate --benchmark test instances, folded into the file batch_measure just wrote.
    out = ROOT / "perf/lightweight.json"
    baseline = out.read_bytes()
    doc = json.loads(baseline)
    version = f"{short} ({build})"
    if doc.get("version") != version:
        raise RuntimeError(f"批量测量写出的版本 {doc.get('version')} 不是装机 {version}")
    with tempfile.TemporaryDirectory(prefix="litegauge-measure-") as tmp:
        samples = benchmark_runs(Path(tmp))
    load = batch_measure.load()
    steady, why = app_sop.steady()
    if not steady and any(not reason.startswith("负载") for reason in why.split("；")):
        print(f"样本作废，未写入速度：测量期间{why}")
        return DEFER
    median = round(statistics.median(samples), 1)
    today = batch_measure.TODAY
    raw_rel = f"perf/raw/first-sample-{short}-{build}.json"
    write_json(ROOT / raw_rel, {"version": version, "samples_ms": samples, "median_ms": median, "runs": RUNS,
                                "method": "open -g -j -n LiteGauge.app --args --benchmark <file>; ready_ms from AppDelegate "
                                          "setup to the first valid CPU reading; test instance ended by its own pid",
                                "load": load, "measured_at": today})
    history = doc.setdefault("history", [])
    for old in doc.get("speed_gui") or []:
        history.append({"section": "speed_gui", "version": version, "replaced_on": today, "reason": "按登记测量脚本重测", "value": old})
    doc["speed_gui"] = [{
        "key": "first_sample", "label": f"进程内首个 CPU 数值（{RUNS} 次中位）",
        "label_en": f"First CPU reading after app setup (median of {RUNS})", "median_ms": median, "runs": RUNS,
        "raw_ms": samples, "headline": True,
        "method": f"已装 {short} 以 --benchmark 启动测试实例（open -g -j -n 后台、不抢焦点，按其写出的 pid 结束，不碰常驻实例），"
                  "AppDelegate 初始化至首个有效 CPU 差分；非完整冷启动；含 1 秒采样窗口",
        "raw": raw_rel, "load": load, "measured_at": today}]
    if out.read_bytes() != baseline:
        print("测量期间证据已被修改，未覆盖 perf/lightweight.json")
        return 1
    write_json(out, doc)
    print(json.dumps({"version": version, "first_sample_median_ms": median, "size": doc.get("size"),
                      "idle_mb": doc.get("idle", {}).get("footprint_mb")}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
