# LiteGauge

“Check for Updates…” queries this product's GitHub Release on demand and offers an upgrade. No metrics are uploaded and no background update polling is added. Automatic-care policy and results stay local; “使用 iCloud 记住配置” in Settings is off by default, and when you turn it on only the protection list is copied to your own iCloud Drive.

[中文](README.md) | **English**

A native macOS dual-Mac monitor: **56 points per Mac**, 116 points including the separator, plus a compact 48-point direct/transit speed column (164 points overall).

From 0.6.1, fixed `直` (direct) and `转` (transit) rows show the Air ↔ Mini file-sync send/receive rate combined, with the current route highlighted. Away from home, unavailable direct links show `—` while transit shows its measured rate. This reads Syncthing's existing loopback statistics; it generates no speed-test traffic and never changes routes. Missing, stale, switched or reset counters stay unknown until a second valid sample. The menu, panel, Settings and `litegauge link on|off` share one switch; `link status --json` exposes both routes.

The panel compares Air and Mini side by side: CPU, used/total memory, pressure, swap and free disk capacity. The peer is read from Cadence's original device cache, using the original sample time and configured interval/TTL. Paused, disconnected or expired sources show unknown readings for that Mac. Sampling and task admission stay with their existing owners.

Agents can use `litegauge resources status --json`: `air` and `mini` contain each Mac's readings; `local` preserves native local readings. `litegauge sessions status --json` returns `hosts.air` and `hosts.mini`, each with its own AI counts and validity. Incomplete data returns exit 1 with explicit `null` values for the affected Mac. These queries never connect to the peer or refresh its sample.

[Website and guide](https://litegauge.tianli.cyou) · [Download](https://github.com/zengtianli/LiteGauge/releases/latest) · [Report an issue](https://github.com/zengtianli/LiteGauge/issues)

<img src="docs/media/menubar.png" width="328" alt="Air and Mini resources and AI activity, with direct and transit speeds">

<img src="docs/media/panel.png" width="304" alt="CPU, memory pressure, swap usage, and free disk space">

These are sample-value renders of the app's own AppKit interface. The [24-second demo](docs/media/demo.mp4) shows that native renderer and live sampling; it is not a recording of mouse interactions.

From 0.6.0, Air and Mini have fixed separate groups. Each shows CPU, memory and disk bars, and working/open main AI sessions for that Mac. There is no combined AI count. Either Mac can be unavailable without clearing the other's valid readings; incomplete coverage shows working/? for that Mac only. The order remains Air, Mini when running on Mini. Each resource changes colour with load; AI remains neutral. CPU turns yellow at 60% and red at 90%; memory follows system pressure; disk turns yellow above 90% used and red at 97%. Unknown resources are grey. Click for exact readings and per-Mac AI summaries.

- **Three focused readings.** CPU and memory update every 2 seconds; disk capacity every 60 seconds. Open the menu or press ⌘R to refresh immediately.
- **Native local sampling.** Swift + AppKit, no third-party runtime dependencies or shell-based polling. Resource collection stays offline; file-sync speed reads only the local loopback API. Explicit update checks contact the release channel. No account is required.
- **Less background work.** Periodic collection pauses during system sleep, display sleep, and screen lock. CPU sampling resets on resume, and the menu bar updates only when visible integer values change.
- **Reclaim memory, close everything by default.** “Run recommendations” or `litegauge care reclaim --yes` quits every unprotected app normally, ends idle system agents and runs one pressure reclaim; with a memory budget, idle apps are closed automatically when the budget is reached. Terminals, Claude, Codex and their network channel, keyboard and window tools and the system interface always stay; the list is editable. Apps are only asked to quit, never forced.
- **Ready for scripts and agents.** The same executable provides `status --json`, `watch` for readings at the app's cadence, and `app status` for the menu-bar instance; GUI and CLI share their collection code and colour thresholds.

## Download and install

Requires **Apple Silicon (M1 or newer) and macOS 14 or later**. Intel builds are not currently provided. The application interface is in Chinese.

1. Download the matching `LiteGauge-<version>-arm64.dmg` from [Releases](https://github.com/zengtianli/LiteGauge/releases/latest).
2. Open the DMG and drag `LiteGauge.app` into `Applications`.
3. Launch LiteGauge from Applications and check the top menu bar. There is no persistent main window; resource diagnosis opens on demand.

A ZIP is also available: extract it and move the app into Applications. Official release artifacts use Developer ID signing, hardened runtime, and Apple notarization. Each Release includes notarization information in `release.json` and hashes in `SHA256SUMS`. To update, quit LiteGauge with ⌘Q from its menu, then replace the old app.

No login item is added automatically, and other monitoring apps are not reconfigured. To start at login, add LiteGauge in macOS System Settings → General → Login Items.

## Use

The detail panel adds an “AI 会话” entry in 0.5.3, showing main sessions, subagents and states from Cadence's derived local cache. Missing, invalid or expired data is unknown. LiteGauge does not collect sessions, read conversations or connect to the network for this feature. Clicking requests Cadence's sessions page; missing installations and unsupported navigation report a reason.

Agents can read the same summary with `litegauge sessions status --json`, check navigation with `litegauge sessions open --dry-run --json`, and request the page with `litegauge sessions open`. Unknown data or unavailable navigation exits 1; unknown counts are JSON `null`.

| Action | Result |
|---|---|
| Click the menu-bar CPU / bars | Open CPU, memory, and disk details |
| ⌘R while the menu is open | Refresh immediately |
| ⌘Q while the menu is open | Quit LiteGauge |
| Resource advice and automatic care | Concrete recommendations, automatic-care status and optional process details |
| Open Activity Monitor | Inspect individual processes |

The native menu supports arrow keys and Return. No global shortcuts are registered. The first CPU value requires approximately one second of sampling.

### Resource advice and automatic care (since 0.3.0)

<img src="docs/media/diagnosis.png" width="740" alt="Resource diagnosis: app rankings, pressure and action controls; sample-value render of the production AppKit view">

Each diagnosis samples for approximately one second and groups executables under their outer app bundle. Memory is `phys_footprint`, including compressed/swapped accounting, so app totals must not be added as physical RAM. Interval CPU uses 100% per core, unlike the menu bar's normalized whole-system 0–100%. Unreadable, exited and newly started processes are marked as unavailable or partial coverage.

Automatic care defaults to off for public installs. After one opt-in, memory pressure must stay elevated for 90 seconds before a scan, with at least two minutes between scans and no additional process scans at normal pressure. Shadowrocket must exceed 512 MiB or OrbStack 2 GiB on two observations. The user must be idle for two minutes, the target must be in the background, and its CPU must be below 10%. Incomplete readings, identity changes and busy apps defer action.

From 0.5.1 a reclaim closes every app by default and keeps only the protected ones. An explicit reclaim (“Run recommendations” or `litegauge care reclaim --yes`) has three steps: quit every running app of the current user normally (menu-bar tools included, protected apps excepted); end idle on-demand system agents (a built-in allowlist, one termination signal each); and run one bounded pressure reclaim with the system's own `memory_pressure`, which takes about a minute while readings rise briefly and pressure shows elevated. Apps only receive a normal quit request and are never forced; one that stays on a save prompt is listed separately as waiting for save confirmation, not closed.

Protected apps are never closed: terminals (Ghostty, iTerm2, Terminal, Warp, kitty, Alacritty, WezTerm), Claude and Codex, their network channel Shadowrocket, Karabiner / yabai / skhd, input methods, LiteGauge itself, system interface processes such as Finder, Dock and Control Center, and any app currently running a `claude` / `codex` command (for example an editor running them in its built-in terminal). aTrust and ASM are protected by default and removable. See `litegauge care protect list`; add with `protect add <bundle id>`.

The memory budget is off by default and is a switch: tick “内存超预算时自动处理” (handle automatically over budget) in the menu, or turn it on in Settings and pick a budget (the first time it starts at half of this Mac's memory); from the command line, `litegauge care budget set 5`. Turning it off remembers the number. Settings also has a “自动关闭闲置应用” (close idle apps automatically) switch (`care budget keep-apps` / `close-apps`): with it off, automatic handling only ends idle agents and reclaims, and closes no app. Once on, the menu-bar app reclaims automatically once used memory has been at the budget for 10 seconds: it closes only unprotected apps that are not frontmost and have not been frontmost for 10 minutes (`care budget idle <minutes>` changes this; 0 keeps only the frontmost app), then runs the other two steps. Two reclaims are at least 8 minutes apart. If usage is still at or above the budget afterwards, the remainder belongs to the system layer, protected apps or apps just used, so nothing is reclaimed for 30 minutes and the advice lists what the memory is made of. The budget only works while the menu-bar app runs, pauses during sleep and screen lock, and restarts the idle clock when you return.

The “异常恢复” (recovery) switch in Settings covers two services only: under sustained elevated pressure, Shadowrocket above 512 MiB has its tunnel reconnected and OrbStack above 2 GiB has its VM backend restarted normally, which briefly interrupts the network or containers; configuration, images and data are kept. At most one per check, a one-hour cooldown after success and six hours after failure. Shadowrocket is never closed; OrbStack is closed like any other app during a reclaim.

A real click on “Run recommendations” first confirms how many apps will be closed. Progress, the apps closed, the apps waiting for save confirmation and memory changes appear at the top; historical results are dated. `care reclaim --yes --json` returns `status`, `apps[]` (each with a `result`: `closed`, `pending_save`, `refused`, `identity_changed`), `pendingSaveApps`, `protectedApps` and the readings; nothing done is `no_action`, quit requests sent but no app closed is `not_completed`, both with `ok: false` and exit code 1, and a preview is `preview`.

Since 0.5.1 browsers are closed like any other app and no longer need the separate 0.4.3 opt-in (`care browsers` is kept for compatibility and has no effect). They stay closed afterwards; discard prompts are never answered automatically; downloads and page tasks can be interrupted, and the browser decides how to restore next time.

Closing releases the current browser footprint. Restarting reloads pages and can increase memory again, so browser care no longer restarts. Explicit `process restart` remains available for operations that actually need application recovery.

Policy and the last 20 results stay in the owner-only `~/Library/Application Support/LiteGauge/` folder. Nothing is uploaded. Explicit `process restart` keeps two normal-session backups per browser without copying cookies, history databases or passwords; ordinary closure does not require a backup. App-accounting and system-used memory are reported separately; other tasks can affect system changes. Quitting waits for ongoing care (a memory reclaim in progress stops at once and ends its pressure tool). Processes are never force-killed. A memory reclaim makes the system drop file cache and other reclaimable memory, so the next file or app launch can be slightly slower.

## Command line

The CLI and the menu-bar app are the same executable and read from the same collection layer (`Sources/Metrics.swift`). The pressure levels and the 90% disk threshold that colour the panel live in that layer too, so the levels the CLI reports match the panel colours. The installed app includes the CLI; no separate runtime is required:

```sh
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status --json
```

Optionally add a shorter command (`bash scripts/install.sh` adds it on first install; inspect any existing entry before replacing it):

```sh
mkdir -p "$HOME/.local/bin"
ln -s /Applications/LiteGauge.app/Contents/MacOS/LiteGauge "$HOME/.local/bin/litegauge"
```

After adding `~/.local/bin` to PATH:

```sh
litegauge status                   # one reading: CPU / memory / disk (about 1 s of sampling)
litegauge status --json            # the same as one JSON object
litegauge diagnose --sort memory --limit 10 --json # rankings, pressure, coverage and advice
litegauge diagnose --sort cpu      # interval CPU ranking (100% = one core)
litegauge care plan --json         # concrete recommendations and reasons to defer or retain
litegauge care enable --yes        # allow abnormal-state recovery of Shadowrocket / OrbStack; care disable pauses it
litegauge care status --json       # settings readback: policy, last check and action results, version, whether the menu-bar instance is running, whether an action is in progress
litegauge care run --dry-run --json # merged into care reclaim: --yes equals care reclaim --yes plus the recovery above
litegauge care reclaim --dry-run --json # list the apps to close, the protected apps and the idle system agents to end; does nothing
litegauge care reclaim --yes       # close unprotected apps, end idle agents, run one bounded pressure reclaim
litegauge care reclaim --yes --keep-apps # leave apps open; agents and pressure reclaim only
litegauge care reclaim --yes --only com.apple.TextEdit --keep-background # quit only the named app normally; --only may repeat
litegauge care budget set 5        # used-memory budget in GiB; when reached the menu-bar app closes idle apps and reclaims; budget off turns it off and remembers the number, budget on restores it, budget status
litegauge care budget keep-apps    # automatic handling closes no app, only ends idle agents and reclaims; budget close-apps restores closing
litegauge care budget idle 10      # automatic reclaim only closes apps not frontmost for this many minutes; 0 keeps only the frontmost app
litegauge care protect list        # protection list: built-in and user entries; protect add|remove <bundle id>, protect reset
litegauge process restart --pid 123 --token 123:1790000000:0 --dry-run --json # read token from diagnosis; --yes performs the action
litegauge watch --count 5 --json   # stream at the app's cadence (every 2 s by default), one JSON object per line (NDJSON)
litegauge watch --interval 10      # one text line every 10 s until Ctrl-C
litegauge app status --json        # whether the menu-bar instance runs: pid, bundle path, version
litegauge app quit --dry-run       # show which instance would quit; use --yes to quit it (same as ⌘Q)
litegauge app quit --yes --pid 123 # quit only the menu-bar instance with pid 123
litegauge config status --json     # the iCloud switch, the sync sentence under it (sync_status), the portable settings (the protection list), whether the app runs
litegauge config export -o gauge.json # the same file as “导出配置…” in Settings; --force to overwrite
litegauge config import gauge.json --yes # backs up, then replaces the protection list; switches, budget and idle threshold stay per Mac
litegauge config sync on --yes     # flip “使用 iCloud 记住配置” (off by default); --dry-run only reports; sync off turns it off
litegauge update check --json      # current version, the GitHub release, whether a newer one exists and how to upgrade; downloads and installs nothing
litegauge update install --dry-run --json # upgrade: only reports which version would replace which; use --yes to download, verify the signature, replace the app and reopen it in the background (does nothing when there is no newer release)
litegauge --version --json
litegauge --help                   # also -h or help; --help / -h after any command or flag only prints help and runs nothing
```

`care reclaim`, `care protect`, `care budget` and `memory.wiredBytes` were added after the last public release (0.4.1): reclaim and budget in 0.5.0; closing apps, the protection list, `--keep-apps` / `--only` / `--keep-background` and `budget idle` in 0.5.1 (the 0.5.0 `care apps` allow-list was replaced by the protection list). `care reclaim --json` reports `status` (`completed`, `not_completed`, `no_action`, `interrupted`; a preview is `preview`), `apps[]`, `closedAppCount`, `pendingSaveApps`, `protectedApps`, `retainedApps`, `beforeBytes` / `afterBytes`, `compressedBeforeBytes` / `compressedAfterBytes`, `candidateCount`, `signalledCount`, `exitedCount`, `stillRunningCount`, `processes[]` and `pressure` (`status`, `performed`, `reachedWarn`, `seconds`, `reason`).

`watch`, `app`, `--version --json`, and the level, percentage, and error-code fields below are available from 0.1.2; 0.1.1 only has `status [--json]`, `--version`, and `--help`. These also take effect from 0.1.2: `-h`, `help`, and `--help` after a command print help (0.1.1 exits 2), and `litegauge` with no arguments only prints usage (0.1.1 goes down the menu-bar app launch path).

Each record of `status --json` and `watch --json`:

| Field | Meaning |
|---|---|
| `ok` | `true` when `errors` is empty |
| `sampledAt` | Sample time, ISO 8601 |
| `cpuPercent` | Usage normalized across the whole processor, 0–100%; `null` before a baseline exists |
| `cpuLevel` | Shared colour level: `warning` at 60%, `critical` at 90%, `null` when unavailable |
| `memory.totalBytes` / `usedBytes` / `compressedBytes` / `swapUsedBytes` | Integer bytes; used memory excludes reclaimable cache; swap is `null` if unreadable |
| `memory.wiredBytes` | Kernel and driver memory that cannot be compressed or swapped; included in `usedBytes`; from 0.5.0 |
| `memory.percent` | Memory used, the menu-bar memory bar |
| `memory.pressureLevel` | System memory pressure: `normal`, `elevated`, `critical`, `unknown`; `memory.pressure` is the Chinese label |
| `memory.level` / `memory.displayLevel` | Pressure maps to green/yellow/red; `displayLevel` is `null` for unknown pressure, shown in grey |
| `disk.totalBytes` / `availableBytes` | Capacity and free space of the APFS container holding the startup Data volume |
| `disk.usedPercent` | Disk used, the menu-bar disk bar |
| `disk.level` / `disk.warnAbovePercent` / `disk.criticalAtPercent` | `warning` (yellow) above 90% used and `critical` (red) at 97%; shared by menu bar and panel |
| `disk.mountPoint` / `disk.volume` | The mount point read, `/System/Volumes/Data`; Chinese display name |
| `disk.sampledAt` | When the disk was read; like the app, `watch` re-reads it every 60 seconds |
| `errors` / `errorCodes` | The error text the panel shows; stable codes `cpu_unavailable`, `memory_unavailable`, `disk_unavailable` |

Missing readings are written as `null`; every key is always present. `app status --json` reports `running`, `instances[]` (`pid`, `bundlePath`, `version`, `build`, `launchedAt`, `sameBundleAsCLI`), and the `cli` bundle the command itself runs from; `app quit --json` reports `targets`, `stillRunning`, `dryRun`, and `pid`. Both count only instances with a menu-bar item (`.accessory` processes that have finished launching); offscreen acceptance runs such as `--ui-self-test` and `--snapshot` are neither listed nor quit.

Exit codes: `0` success; `1` collection failure (`ok: false`) or `app quit` could not finish within 5 seconds; `2` invalid arguments or a missing confirmation flag (the reason goes to stderr; with `--json`, stdout also carries `{"ok": false, "error": {"code": "usage", "message": …}}`). Every failed `--json` result carries `error.code` and `error.message` next to the keys it already had; `care status --json` also reports `version`, `build`, `menuBarAppRunning`, `inProgress` and `inProgressPid`. `litegauge --help` lists the read commands, the write commands, each command's JSON shape and the items that exist only in the window. `--help` and `--version` return immediately. `litegauge` with no arguments prints usage and exits 2; it never starts the menu-bar app. Start the app from Applications or with `open -g -j /Applications/LiteGauge.app`.

| Menu-bar app | Command line |
|---|---|
| Menu-bar CPU percentage, memory and disk bars, accessibility value | First line of `status`; `cpuPercent`, `memory.percent`, `disk.usedPercent` |
| Detail panel: memory use and pressure colour, swap, free disk and the 90% warning | Lines 2–3 of `status`; `memory.*`, `disk.*` and their `level` |
| Updates every 2 seconds, disk every 60 seconds | `watch` |
| ⌘R refresh | Every `status` is a fresh sample including disk (it does not refresh the running menu-bar item) |
| "Unavailable" on read failure | `errors` / `errorCodes`, exit code 1 |
| ⌘Q quit | `app quit --yes` (check the target with `--dry-run` first) |
| Whether the menu-bar item is there | `app status` |
| Concrete advice / automatic-care status | `care plan` / `care status` |
| Allow / pause Shadowrocket and OrbStack recovery | `care enable --yes` / `care disable` |
| “Run recommendations”: close unprotected apps and reclaim | `care reclaim --dry-run` to preview, `care reclaim --yes` to execute (`care run` is the same) |
| The “handle automatically over budget” switch in the menu / Settings, and the budget | `care budget on` / `care budget off`, `care budget set <GiB>` |
| The iCloud switch, “导出配置…” and “导入配置…” in Settings | `config sync on --yes` / `config sync off --yes`, `config export -o <file>`, `config import <file> --yes`; read back with `config status` (including the sync sentence under the switch) |
| “检查更新…” and “升级到新版…” | `update check`; `update install --yes` (the same path as the window; `--dry-run` first to see what it would do; does nothing when there is no newer release, and returns `manual_install` with the package address where the window shows “下载新版…”) |
| The “close idle apps automatically” switch in Settings, and the idle time | `care budget close-apps` / `care budget keep-apps`, `care budget idle <minutes>`; protection list `care protect list` |

GUI-only: clicking to open the menu, arrow-key menu navigation, "Open Activity Monitor" (use `ps` or `top` from the command line), and the automatic pause during sleep and screen lock (internal app behaviour with no user action). Development and acceptance flags `--ui-self-test`, `--snapshot`, `--benchmark`, and `--background` are listed in `--help`.

<!-- lightweight:start -->
## Resource use

| Download | Idle memory | Idle CPU | First CPU reading after app setup (median of 5) |
|---|---|---|---|
| **1.7 MB** (installed 1.9 MB) | **15.7 MB** | **0%** | **1.2 s** |

Native AppKit; no third-party runtime or network requests; shared 2-second CPU/memory sampling, 60-second disk-capacity cache, redraw only on visible-value changes.

<sub>v0.1.2 (3) · Mac16,12 / Apple M4 / macOS 27.2 · Notarized release; menu closed; CPU/memory every 2 seconds and disk every 60 seconds. Measured on the resident instance after about 13 hours of running (not freshly launched); 60-second CPU window, footprint read in the same pass. · measured 2026-10-01. Measured on the listed device; re-measured for each version. Memory uses phys_footprint; CPU is CPU time ÷ wall time over a 60-second sampling window; sizes in decimal MB. Raw data: [perf/lightweight.json](perf/lightweight.json).</sub>
<!-- lightweight:end -->

These are measurements on the listed device and refresh settings, not a guarantee for every Mac. Time to the first CPU value includes its sampling interval and is not a full cold-start measurement.

## FAQ

**Why does memory usage differ from another tool?** Memory is displayed in GiB. Used memory excludes reclaimable file cache and purgeable pages. Pressure comes from the system; utilization alone does not indicate a shortage.

**Why does free disk space differ from Finder?** LiteGauge reads the startup Data volume's APFS container capacity and currently available blocks. It does not add capacities across shared volumes or include purgeable space. Disk values use decimal GB. The bar shows used capacity; the detail panel shows available space.

**Does it monitor network, temperature, fans, or individual processes?** Air ↔ Mini file-sync direct/transit speeds and per-process CPU/memory advice are included. General internet speed, sensors, fan control, disk throughput and history charts are not included.

**Can I keep Stats installed too?** Yes. They have different names and bundle identifiers. Running both adds their resource use together; keep both installed and run one at a time if you prefer.

**Where is the menu-bar item?** Confirm the app is running, then check whether a menu-bar manager or the display notch is hiding it. Try quitting other menu-bar apps to make room.

**What if macOS refuses to open it?** Confirm you downloaded from this repository's Release and compare the file with `SHA256SUMS`. Official artifacts are signed and notarized. If it still fails, report the full message, macOS version, chip, and app version in an Issue. Do not disable Gatekeeper.

**How do I uninstall it?** Quit LiteGauge from its menu and move the app to Trash. Remove the optional CLI symlink and login item if you added them. Delete `~/Library/Application Support/LiteGauge/` to remove local automatic-care policy and results too.

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
bash scripts/install.sh  # Install to /Applications, plus ~/.local/bin/litegauge; the old app goes to the Trash
bash scripts/install.sh --restart  # If the installed copy is running: quit, replace, relaunch in the background
```

Tests cover CPU deltas and wraparound, memory accounting and underflow, disk caching and refresh, overlapping sleep/lock state, pressure levels and colour thresholds, JSON fields, command-line parsing, `watch` streaming, and live system reads. `Sources/Metrics.swift` provides shared collection (including levels and thresholds), `Sources/App.swift` implements the interface, `Sources/CLI.swift` parses commands and formats output, and `Sources/main.swift` handles entry points.

Release maintainers can use `scripts/package-release.sh` to build signed, notarized ZIP and DMG artifacts. Set `CODE_SIGN_IDENTITY`, then use `NOTARY_PROFILE`, or `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `NOTARY_KEY_FILE`. Outputs include `build/release/release.json` and `SHA256SUMS`. Never commit credentials.

## License and feedback

[MIT License](LICENSE). LiteGauge is an independent minimal tool using Apple system APIs, not a fork of Stats. The icon was generated with OpenAI image generation; provenance is recorded in `icon/provenance.json`.

[Issues](https://github.com/zengtianli/LiteGauge/issues) and contributions are welcome. Include your app version, system, chip, reproduction steps, and expected behavior. Check screenshots and CLI output for personal information before posting.
