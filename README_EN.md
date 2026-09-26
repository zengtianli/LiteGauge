# LiteGauge · Minimal system monitor

[中文](README.md) | **English**

A private native macOS menu-bar utility for CPU, memory and startup-disk capacity. The menu-bar item is **56 points wide**: a stacked CPU label and percentage, then two vertical utilization bars for memory and disk. Click for detailed values, memory pressure and swap usage.

CPU and memory update every 2 seconds; disk capacity every 60 seconds. Opening the menu or pressing ⌘R refreshes disk capacity immediately. The first CPU result requires approximately one second of sampling. Sampling pauses during sleep, display sleep or screen lock and resets its CPU baseline on resume.

Built with Apple frameworks; no third-party runtime dependencies, network access or shell-based collection. Version 0.1 does not include process rankings, network monitoring, sensors, fan control or history charts. The menu links to Activity Monitor.

## Run locally

- Build: `bash build.sh` → `build/LiteGauge.app`, Apple Silicon / macOS 14+.
- Double-click the app. With the menu open, ⌘R refreshes and ⌘Q quits; arrow keys and Return operate the native menu.
- After installation is approved: `bash scripts/install.sh` → `/Applications/LiteGauge.app` and `~/.local/bin/litegauge`.
- No login item is enabled automatically; Stats preferences are not changed.
- Local builds are ad-hoc signed and are not notarized distribution artifacts.

## CLI

```sh
build/LiteGauge.app/Contents/MacOS/LiteGauge status
build/LiteGauge.app/Contents/MacOS/LiteGauge status --json
# After installation
litegauge status --json
```

GUI and CLI share `Sources/Metrics.swift`. JSON fields are `cpuPercent`, `memory`, `disk`, `sampledAt`, and `errors`. Byte counts are integers and dates use ISO 8601. CPU is normalized across the whole processor (0–100%); a snapshot without a previous sample returns null.

Exit codes: 0 success, 1 collection failed, 2 invalid arguments. CLI CPU sampling takes approximately one second; `--help` and `--version` return immediately.

## Measurement definitions

Memory is shown in GiB. Used memory excludes reclaimable file cache and purgeable pages. Pressure comes from the system; utilization alone does not indicate memory shortage.

Disk values use decimal GB and the startup Data volume's APFS container capacity and currently available blocks. Shared-volume capacities are not added together. Purgeable space is not added back, so available space may differ from Finder. The bar shows used capacity; the detail panel shows free capacity.

Performance evidence lives in `perf/lightweight.json`. The shared script's `footprint_mb` is MiB; values displayed as MB are converted to decimal.

<!-- lightweight:start -->
Performance measurement of the current build is in progress. See `perf/lightweight.json`.
<!-- lightweight:end -->

## Verification

`bash build.sh --test-only` covers CPU deltas and counter wraparound, memory accounting, disk caching and refresh, overlapping sleep/lock state, and live system reads. An isolated mutation check confirmed that an incorrect CPU formula is rejected.

`LiteGauge --snapshot <path.png>` renders the actual detail panel offscreen without activating windows. Current verification scope and limitations are recorded in `handoffs/current.md`.

The app icon was generated with OpenAI's built-in image_gen. Provenance, prompt and deterministic packaging parameters are in `icon/provenance.json`. The requested Seedream service failed its TLS connection and produced no image.
