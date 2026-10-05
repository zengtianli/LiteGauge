# LiteGauge · 轻仪

菜单“检查更新…”按需查询本产品的 GitHub Release，显示正式版本和升级入口；不上传系统采样结果，也不增加后台更新轮询。自动处理策略与结果只保存在本机。

**中文** | [English](README_EN.md)

只占 **56 点菜单栏**的原生 macOS 系统监控：CPU、内存、启动磁盘，一眼看完。

[官网下载与教程](https://litegauge.tianli.cyou) · [下载最新版](https://github.com/zengtianli/LiteGauge/releases/latest) · [报告问题](https://github.com/zengtianli/LiteGauge/issues)

<img src="docs/media/menubar.png" width="112" alt="菜单栏：CPU 和内存、磁盘竖条">

<img src="docs/media/panel.png" width="304" alt="轻仪详情：CPU、内存压力、交换空间与磁盘剩余容量">

以上为应用同源 AppKit 界面的示例值渲染。[24 秒界面演示](docs/media/demo.mp4) 展示同源原生界面与实时采样；不是鼠标操作录屏。

CPU 标签与百分比上下排列，右侧两根竖条依次表示内存、磁盘的已用比例。点击展开完整数值、内存压力、交换空间和磁盘剩余量。

- **专注三项数据。** CPU/内存每 2 秒更新，磁盘容量每 60 秒更新；展开菜单或按 ⌘R 立即刷新。
- **原生本机采集。** Swift + AppKit，无第三方运行依赖，不启动 shell 采集；采样离线，只有主动检查更新时访问发行渠道，无需账号。
- **减少后台工作。** 屏幕休眠、系统睡眠或锁屏时暂停周期采集，恢复后重建 CPU 基线；可见整数变化时才更新菜单栏。
- **建议操作，自动处理。** 菜单「资源建议与自动处理…」直接给出具体建议。一次允许后自动照料异常 Shadowrocket / OrbStack；0.4.3 可另行允许正常关闭 Dia / Chrome，关闭后保持关闭，不用逐个选应用。显示应用计账与系统已用内存前后变化，以及尚未处理的原因。
- **也能用于脚本和 agent。** 同一个程序提供 `status --json`、按 App 节奏连续输出的 `watch`，以及查询菜单栏实例的 `app status`；GUI 与 CLI 共用采集逻辑和配色阈值。

## 下载与安装

需要 **Apple Silicon（M1 或更新）与 macOS 14 或更新版本**。当前不提供 Intel 构建，应用界面为中文。

1. 在 [Releases](https://github.com/zengtianli/LiteGauge/releases/latest) 下载对应版本的 `LiteGauge-<版本>-arm64.dmg`。
2. 打开 DMG，将 `LiteGauge.app` 拖到 `Applications`。
3. 在「应用程序」中打开 LiteGauge，在屏幕顶部菜单栏查看读数。它没有常驻主窗口，资源诊断窗口按需打开。

也可下载 ZIP，解压后将应用拖入「应用程序」。正式发行包使用 Developer ID 签名、hardened runtime，并经过 Apple 公证；公证与 SHA-256 信息随每次 Release 的 `release.json` / `SHA256SUMS` 提供。更新前在轻仪菜单按 ⌘Q 退出，然后替换旧应用。

不会自动添加登录项或更改其他监控软件。需要开机启动时，在 macOS「系统设置 → 通用 → 登录项」中添加 LiteGauge。

## 使用

| 操作 | 结果 |
|---|---|
| 点击菜单栏 CPU / 竖条 | 展开 CPU、内存、磁盘详情 |
| 菜单内 ⌘R | 立即刷新 |
| 菜单内 ⌘Q | 退出 LiteGauge |
| 「资源建议与自动处理…」 | 查看具体建议、自动处理状态和占用明细；无需逐个点选 |
| 「打开活动监视器」 | 进一步查看进程占用 |

原生菜单支持方向键和回车。没有全局快捷键。启动后首次 CPU 数值需要约 1 秒采样。

### 资源建议与自动处理（0.3.0 起）

<img src="docs/media/diagnosis.png" width="740" alt="具体操作建议与自动处理状态，同源 AppKit 示例值渲染">

一次诊断约采样 1 秒，窗口显示应用路径内的各个进程合计。内存使用 `phys_footprint`，包含压缩及换出计账，不能直接相加当作物理 RAM；CPU 为区间使用率，100% 表示一个核心，与菜单栏整机 0–100% 的口径不同。受权限限制、采样期间退出或新启动的进程会标明不可用/部分覆盖。

公开版本默认关闭自动处理。首次允许后，压力持续偏高 90 秒才检查后台应用，最多每 2 分钟一次；正常压力时不增加进程扫描。Shadowrocket 超过 512 MiB、OrbStack 超过 2 GiB，连续两次读数确认，且你空闲 2 分钟、目标不在前台、后台 CPU 低于 10% 时才安排重启。读数不完整、身份不符或应用忙碌时暂缓。

OrbStack 正常停启会短暂中断容器/虚拟机，Shadowrocket 重连会短暂断网；配置、镜像和数据保留。每次后台自动检查最多处理一个应用，基本服务成功后至少观察 1 小时，失败后暂停 6 小时。aTrust、编辑器和索引器保留；普通虚拟机占用或稳定索引内存会给出保留建议。也可用统一的「按建议处理」立即检查，不需要逐项选择。

主动点击「按建议处理」会正常关闭已允许的 Dia / Chrome，并保持关闭。浏览器主动关闭不受内存阈值、压力、空闲、CPU、前台或旧重启观察期限制；每项仍核对权限、完整内存读数与真实应用身份，保存或离开页面提示由浏览器处理。异常后台服务仍按原保护条件正常恢复。暂停后台调度保留已授予的手动权限；没有可执行项时按钮为「复查并处理」。顶部显示进度、实际项数、内存前后变化，历史结果标明时间。CLI 的 `care run --yes --json` 返回 `status`、`attemptedCount`、`performedCount`；零操作为 `no_action`、`ok: false`、退出码 1，预览为 `preview`。

0.4.3 的「允许关闭浏览器…」另行允许一次 Dia / Chrome。原有重启许可不会自动变成关闭许可。后台自动关闭仍要求持续高压力、Dia 超过 3 GiB / Chrome 超过 2 GiB、两次高读数、空闲 2 分钟、浏览器不在前台且低负载；成功或失败后观察 6 小时。正常关闭后不再打开，不自动点击丢弃表单；下载和页面任务可能中断，浏览器自身决定下次打开如何恢复。可统一暂停关闭浏览器。

关闭浏览器用于释放当前占用；关闭再打开会重新加载页面并使内存回升，因此浏览器照料不再采用重启。`process restart` 仍供明确需要恢复应用的操作使用。

策略和最近 20 条处理结果仅保存在本机 `~/Library/Application Support/LiteGauge/`，不上传。明确请求 `process restart` 时保留最近两份普通会话备份，不复制 Cookie、历史数据库或密码；普通关闭不依赖会话备份。应用计账内存与系统已用内存分别记录，系统前后差值也可能受其他任务影响。退出时等待正在执行的后台处理完成；不强制结束进程或清空系统缓存。

## 命令行

命令行和菜单栏是同一个程序，读数来自同一采集层（`Sources/Metrics.swift`）；面板配色用的压力等级和磁盘 90% 阈值也在这一层，所以命令行报告的等级与面板颜色一致。安装应用后即可使用，无需另装运行环境：

```sh
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status --json
```

可选地添加简短命令（`bash scripts/install.sh` 首次安装时会自动添加；已有同名文件时请先检查）：

```sh
mkdir -p "$HOME/.local/bin"
ln -s /Applications/LiteGauge.app/Contents/MacOS/LiteGauge "$HOME/.local/bin/litegauge"
```

将 `~/.local/bin` 加入 PATH 后：

```sh
litegauge status                   # 一次读数：CPU / 内存 / 磁盘（采样约 1 秒）
litegauge status --json            # 同上，输出一个 JSON 对象
litegauge diagnose --sort memory --limit 10 --json # 应用占用、系统压力、覆盖范围和处理建议
litegauge diagnose --sort cpu      # 按区间 CPU 排序（100%=一个核心）
litegauge care plan --json         # 具体建议、保留原因、待处理条件
litegauge care enable --yes        # 一次允许后台自动处理；care disable 暂停
litegauge care browsers --yes      # 另行允许正常关闭 Dia / Chrome；--disable 可单独暂停
litegauge care status --json       # 策略、最近检查及处理结果
litegauge care run --dry-run --json # 预览统一处理；改为 --yes 即执行
litegauge process restart --pid 123 --token 123:1790000000:0 --dry-run --json # token 从诊断结果读取；改 --yes 才执行
litegauge watch --count 5 --json   # 按 App 节奏（默认每 2 秒）连续输出，每行一个 JSON（NDJSON）
litegauge watch --interval 10      # 每 10 秒一行文本，Ctrl-C 结束
litegauge app status --json        # 菜单栏实例是否在运行：pid、bundle 路径与版本
litegauge app quit --dry-run       # 查看将退出哪个实例；换成 --yes 才实际退出（与 ⌘Q 相同）
litegauge app quit --yes --pid 123 # 只退出 pid 为 123 的菜单栏实例
litegauge --version --json
litegauge --help                   # 也可用 -h、help；任一命令或参数后加 --help / -h 也只显示帮助，不执行
```

`watch`、`app`、`--version --json` 与下表中的等级、百分比、错误代码字段自 0.1.2 起提供；0.1.1 只有 `status [--json]`、`--version` 和 `--help`。以下行为也自 0.1.2 起生效：`-h`、`help` 与「命令后加 `--help`」显示帮助（0.1.1 中退出 2），`litegauge` 不带参数只打印用法（0.1.1 中会走启动菜单栏 App 的路径）。

`status --json` 与 `watch --json` 的每条记录：

| 字段 | 含义 |
|---|---|
| `ok` | `errors` 为空时为 `true` |
| `sampledAt` | 采样时间，ISO 8601 |
| `cpuPercent` | 整个处理器归一化的 0–100% 使用率；尚无基线时为 `null` |
| `memory.totalBytes` / `usedBytes` / `compressedBytes` / `swapUsedBytes` | 整数字节；已用量扣除可回收缓存，交换读取失败时为 `null` |
| `memory.percent` | 内存已用比例，即菜单栏的内存竖条 |
| `memory.pressureLevel` | 系统内存压力：`normal`、`elevated`、`critical`、`unknown`；`memory.pressure` 为对应中文标签 |
| `memory.level` | 面板配色：`normal` 绿、`warning` 橙、`critical` 红 |
| `disk.totalBytes` / `availableBytes` | 启动盘 Data 卷所在 APFS 容器的容量与可用空间 |
| `disk.usedPercent` | 磁盘已用比例，即菜单栏的磁盘竖条 |
| `disk.level` / `disk.warnAbovePercent` | 已用超过 `warnAbovePercent`（90）时为 `warning`，面板进度条变橙 |
| `disk.mountPoint` / `disk.volume` | 读取的挂载点 `/System/Volumes/Data`；中文显示名 |
| `disk.sampledAt` | 磁盘读取时间；`watch` 与 App 一样每 60 秒重读一次 |
| `errors` / `errorCodes` | 面板显示的错误文字；稳定代码 `cpu_unavailable`、`memory_unavailable`、`disk_unavailable` |

缺少的读数写为 `null`，键始终存在。`app status --json` 输出 `running`、`instances[]`（`pid`、`bundlePath`、`version`、`build`、`launchedAt`、`sameBundleAsCLI`）和命令行自身所在的 `cli` 包；`app quit --json` 输出 `targets`、`stillRunning`、`dryRun`、`pid`。两者只计入带菜单栏图标的实例（已完成启动的 `.accessory` 进程）；`--ui-self-test`、`--snapshot` 等离屏验收进程不列出，也不会被退出。

退出码：`0` 成功；`1` 采集失败（`ok: false`），或 `app quit` 未能在 5 秒内退出；`2` 参数错误（只写 stderr）。`--help` 与 `--version` 立即返回。`litegauge` 不带参数只打印用法并退出 2，不会启动菜单栏 App；启动 App 请从「应用程序」打开，或运行 `open -g -j /Applications/LiteGauge.app`。

| 菜单栏 App | 命令行 |
|---|---|
| 菜单栏 CPU 百分比、内存与磁盘竖条、无障碍读数 | `status` 首行；`cpuPercent`、`memory.percent`、`disk.usedPercent` |
| 详情面板：内存用量与压力颜色、交换空间、磁盘剩余与 90% 提醒 | `status` 第 2–3 行；`memory.*`、`disk.*` 及其 `level` |
| 每 2 秒更新，磁盘每 60 秒 | `watch` |
| ⌘R 立即刷新 | `status` 每次都是含磁盘的新采样（不会让运行中的菜单栏刷新） |
| 读取失败显示“不可用” | `errors` / `errorCodes`，退出码 1 |
| ⌘Q 退出 | `app quit --yes`（先用 `--dry-run` 查看目标） |
| 菜单栏图标是否在 | `app status` |
| 具体资源建议 / 自动处理状态 | `care plan` / `care status` |
| 一次允许 / 暂停后台自动处理 | `care enable --yes` / `care disable` |
| 统一处理已允许的异常后台服务 | `care run --dry-run` 预览，`care run --yes` 执行 |

只在界面里做的操作：点击展开菜单、方向键浏览菜单、「打开活动监视器」（命令行直接用 `ps` 或 `top`），以及睡眠、锁屏时自动暂停采样（App 内部行为，没有用户操作）。开发与验收参数 `--ui-self-test`、`--snapshot`、`--benchmark`、`--background` 见 `--help`。

<!-- lightweight:start -->
## 资源占用

| 安装包 | 空闲内存 | 空闲 CPU | 进程内首个 CPU 数值（5 次中位） |
|---|---|---|---|
| **1.7 MB**（装好后 1.9 MB） | **15.7 MB** | **0%** | **1.2 s** |

原生 AppKit；无第三方运行依赖和网络请求；CPU/内存共用2秒采样器，磁盘容量缓存60秒；数值变化时才重绘。

<sub>v0.1.2 (3) · Mac16,12 / Apple M4 / macOS 27.2 · 公证发行版；菜单收起，CPU/内存每2秒、磁盘每60秒；测量已连续运行约13小时的常驻实例（非刚启动），M4/16 GiB 日常负载 · 2026-10-01。数字来自所列设备实测，版本更新后重新测量。内存口径为 phys_footprint；CPU 为 60 秒采样窗内 CPU 时间 ÷ 墙钟；大小按十进制 MB。原始数据见 [perf/lightweight.json](perf/lightweight.json)。</sub>
<!-- lightweight:end -->

这组数据来自所列设备和刷新设置，并不保证每台 Mac 都相同。首个 CPU 数值的耗时包含采样等待，不等于完整冷启动耗时。

## 常见问题

**为什么内存使用率与其他工具不同？** 内存以 GiB 显示；已用量扣除可回收文件缓存和可清除页。内存压力读取系统级别，不能仅凭使用率判断内存不足。

**为什么磁盘剩余量与 Finder 不同？** LiteGauge 读取启动盘 Data 卷所在 APFS 容器的总容量和当前可用块，不累加共享容量的多个卷，也不加回可清除空间。磁盘以十进制 GB 显示；竖条为已用比例，详情为剩余容量。

**能监控网络、温度、风扇或各进程吗？** 资源诊断支持应用与进程的内存/CPU 占用排行及受控处理；没有网络速度、传感器、风扇控制、磁盘读写速率或历史曲线。也可从菜单打开系统活动监视器。

**可以与 Stats 一起安装吗？** 可以，两者使用不同名称和应用标识。并行运行的资源占用会相加；保留两款、平时只运行一款即可。

**找不到菜单栏图标怎么办？** 确认应用已启动；检查菜单栏管理工具或刘海屏是否隐藏了该项目。尝试退出其他占据菜单栏的项目后再查看。

**macOS 提示无法打开怎么办？** 先确认下载自本仓库的 Release，并对照 `SHA256SUMS`。正式包已签名与公证；若仍报错，请在 Issue 附上完整提示、macOS 版本、芯片型号和应用版本。请勿关闭 Gatekeeper。

**如何卸载？** 在轻仪菜单退出，把 `LiteGauge.app` 移到废纸篓；若手动添加了 CLI 软链或登录项，再移除相应入口。自动处理策略和结果在 `~/Library/Application Support/LiteGauge/`，需要彻底移除时可一起删除。

## 从源码构建

需要 Apple Silicon Mac，以及提供 Swift 5.9 或更新版本的 Xcode Command Line Tools / Xcode。可先运行 `xcode-select --install` 安装工具。

```sh
git clone https://github.com/zengtianli/LiteGauge.git
cd LiteGauge
bash build.sh
open build/LiteGauge.app
```

构建脚本先运行测试，再生成 `build/LiteGauge.app`，默认使用本机 ad-hoc 签名；源码构建不是已公证发行包。脚本使用标准 `xcrun` 工具链，不依赖开发者的其他目录。需要指定 Xcode 时可设置 `DEVELOPER_DIR`。

```sh
bash build.sh --test-only
bash scripts/install.sh  # 首次安装到 /Applications，并添加 ~/.local/bin/litegauge；旧版移入废纸篓
bash scripts/install.sh --restart  # 已装版正在运行时：退出、替换后在后台重新启动
```

测试覆盖 CPU 差分与溢出、内存扣除与下溢、磁盘缓存与刷新、睡眠/锁屏叠加状态、压力等级与配色阈值、JSON 字段、命令行参数解析、`watch` 连续输出及真实系统读取。`Sources/Metrics.swift` 为 GUI/CLI 共用采集层（含等级与阈值），`Sources/App.swift` 负责菜单栏与详情，`Sources/CLI.swift` 负责命令解析与输出，`Sources/main.swift` 处理入口。

发布维护者可使用 `scripts/package-release.sh` 构建签名、公证的 ZIP 与 DMG。通过环境变量提供 `CODE_SIGN_IDENTITY`，并配置 `NOTARY_PROFILE`，或 `ASC_KEY_ID`、`ASC_ISSUER_ID` 和 `NOTARY_KEY_FILE`。脚本输出 `build/release/release.json` 与 `SHA256SUMS`；凭据不得提交。

## 许可与反馈

采用 [MIT License](LICENSE)。这是独立实现的极简工具，使用 Apple 系统 API，不是 Stats 的分支。图标由 OpenAI image generation 生成，来源信息保存在 `icon/provenance.json`。

欢迎提交 [Issue](https://github.com/zengtianli/LiteGauge/issues) 或改进。报错请提供版本、系统、芯片、复现步骤和预期行为；截图与 CLI 输出提交前请检查个人信息。
