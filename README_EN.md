# LiteGauge

[中文](README.md) | **English**

A native macOS system monitor in **56 points of menu-bar space**: CPU, memory, and startup-disk capacity at a glance.

[Website and guide](https://litegauge.tianli.cyou) · [Download](https://github.com/zengtianli/LiteGauge/releases/latest) · [Report an issue](https://github.com/zengtianli/LiteGauge/issues)

<img src="docs/media/menubar.png" width="112" alt="Compact CPU, memory, and disk menu-bar item">

<img src="docs/media/panel.png" width="304" alt="CPU, memory pressure, swap usage, and free disk space">

These are sample-value renders of the app's own AppKit interface. The [24-second demo](docs/media/demo.mp4) shows that native renderer and live sampling; it is not a recording of mouse interactions.

A stacked CPU label and percentage are followed by two vertical bars for memory and disk utilization. Click for exact values, memory pressure, swap usage, and free disk space.

- **Three focused readings.** CPU and memory update every 2 seconds; disk capacity every 60 seconds. Open the menu or press ⌘R to refresh immediately.
- **Native and offline.** Swift + AppKit, no third-party runtime dependencies, network requests, shell-based polling, or account.
- **Less background work.** Periodic collection pauses during system sleep, display sleep, and screen lock. CPU sampling resets on resume, and the menu bar updates only when visible integer values change.
- **Ready for scripts.** The same executable provides `status --json`; GUI and CLI share their data collection code.

## Download and install

Requires **Apple Silicon (M1 or newer) and macOS 14 or later**. Intel builds are not currently provided. The application interface is in Chinese.

1. Download `LiteGauge-0.1.0-arm64.dmg` from [Releases](https://github.com/zengtianli/LiteGauge/releases/latest).
2. Open the DMG and drag `LiteGauge.app` into `Applications`.
3. Launch LiteGauge from Applications and check the top menu bar. There is no Dock icon or regular main window.

A ZIP is also available: extract it and move the app into Applications. Official release artifacts use Developer ID signing, hardened runtime, and Apple notarization. Each Release includes notarization information in `release.json` and hashes in `SHA256SUMS`. To update, quit LiteGauge with ⌘Q from its menu, then replace the old app.

No login item is added automatically, and other monitoring apps are not reconfigured. To start at login, add LiteGauge in macOS System Settings → General → Login Items.

## Use

| Action | Result |
|---|---|
| Click the menu-bar CPU / bars | Open CPU, memory, and disk details |
| ⌘R while the menu is open | Refresh immediately |
| ⌘Q while the menu is open | Quit LiteGauge |
| Open Activity Monitor | Inspect individual processes |

The native menu supports arrow keys and Return. No global shortcuts are registered. The first CPU value requires approximately one second of sampling.

## Command line

The installed app includes the CLI; no separate runtime is required:

```sh
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status --json
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge --help
```

Optionally add a shorter command; inspect any existing entry before replacing it:

```sh
mkdir -p "$HOME/.local/bin"
ln -s /Applications/LiteGauge.app/Contents/MacOS/LiteGauge "$HOME/.local/bin/litegauge"
# After adding ~/.local/bin to PATH:
litegauge status --json
```

JSON fields are `cpuPercent`, `memory`, `disk`, `sampledAt`, and `errors`. Byte counts are integers and dates use ISO 8601. CPU usage is normalized across the entire processor, from 0 to 100%. Unavailable readings are empty; collection failures appear in `errors`.

Exit codes: `0` success, `1` collection failure, `2` invalid arguments. CPU sampling takes approximately one second; `--help` and `--version` return immediately.

<!-- lightweight:start -->
## Resource use

| Download | Idle memory | Idle CPU | First CPU reading after app setup (single run) |
|---|---|---|---|
| **1.6 MB** (installed 1.8 MB) | **14.7 MB** | **0.86%** | **1.3 s** |

Native AppKit; no third-party runtime or network requests; shared 2-second CPU/memory sampling, 60-second disk-capacity cache, redraw only on visible-value changes.

<sub>v0.1.0 · Mac16,12 / Apple M4 / macOS 27.2 · Notarized release; menu closed; CPU/memory every 2 seconds and disk every 60 seconds. Settled 45 seconds before a 60-second CPU window; footprint sampled separately afterward. · measured 2026-09-26. Measured on the listed device; re-measured for each version. Memory uses phys_footprint; CPU is CPU time ÷ wall time over a 60-second sampling window; sizes in decimal MB. Raw data: [perf/lightweight.json](perf/lightweight.json).</sub>
<!-- lightweight:end -->

These are measurements on the listed device and refresh settings, not a guarantee for every Mac. Time to the first CPU value includes its sampling interval and is not a full cold-start measurement.

## FAQ

**Why does memory usage differ from another tool?** Memory is displayed in GiB. Used memory excludes reclaimable file cache and purgeable pages. Pressure comes from the system; utilization alone does not indicate a shortage.

**Why does free disk space differ from Finder?** LiteGauge reads the startup Data volume's APFS container capacity and currently available blocks. It does not add capacities across shared volumes or include purgeable space. Disk values use decimal GB. The bar shows used capacity; the detail panel shows available space.

**Does it monitor network, temperature, fans, or individual processes?** This version focuses on CPU, memory, and startup-disk capacity. It does not include network speed, sensors, fan control, disk throughput, or history charts. Open Activity Monitor from the menu for process details.

**Can I keep Stats installed too?** Yes. They have different names and bundle identifiers. Running both adds their resource use together; keep both installed and run one at a time if you prefer.

**Where is the menu-bar item?** Confirm the app is running, then check whether a menu-bar manager or the display notch is hiding it. Try quitting other menu-bar apps to make room.

**What if macOS refuses to open it?** Confirm you downloaded from this repository's Release and compare the file with `SHA256SUMS`. Official artifacts are signed and notarized. If it still fails, report the full message, macOS version, chip, and app version in an Issue. Do not disable Gatekeeper.

**How do I uninstall it?** Quit LiteGauge from its menu and move the app to Trash. Remove the optional CLI symlink and login item if you added them. The app does not store monitoring history.

## Build from source

Requires an Apple Silicon Mac and Xcode Command Line Tools / Xcode with Swift 5.9 or newer. Run `xcode-select --install` if the tools are missing.

```sh
git clone https://github.com/zengtianli/LiteGauge.git
cd LiteGauge
bash build.sh
open build/LiteGauge.app
```

The build script runs tests first, then creates `build/LiteGauge.app` with a local ad-hoc signature. A source build is not a notarized release. It uses standard `xcrun` tooling and requires no other developer checkout. Set `DEVELOPER_DIR` to select a specific Xcode installation.

```sh
bash build.sh --test-only
bash scripts/install.sh  # First install to /Applications, plus ~/.local/bin/litegauge
```

Tests cover CPU deltas and wraparound, memory accounting and underflow, disk caching and refresh, overlapping sleep/lock state, and live system reads. `Sources/Metrics.swift` provides shared collection, `Sources/App.swift` implements the interface, and `Sources/main.swift` handles entry points.

Release maintainers can use `scripts/package-release.sh` to build signed, notarized ZIP and DMG artifacts. Set `CODE_SIGN_IDENTITY`, then use `NOTARY_PROFILE`, or `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `NOTARY_KEY_FILE`. Outputs include `build/release/release.json` and `SHA256SUMS`. Never commit credentials.

## License and feedback

[MIT License](LICENSE). LiteGauge is an independent minimal tool using Apple system APIs, not a fork of Stats. The icon was generated with OpenAI image generation; provenance is recorded in `icon/provenance.json`.

[Issues](https://github.com/zengtianli/LiteGauge/issues) and contributions are welcome. Include your app version, system, chip, reproduction steps, and expected behavior. Check screenshots and CLI output for personal information before posting.
