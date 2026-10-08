# LiteGauge · 轻仪

菜单“检查更新…”按需查询本产品的 GitHub Release，显示正式版本和升级入口；不上传系统采样结果，也不增加后台更新轮询。自动处理策略与结果只保存在本机；设置里的「使用 iCloud 记住配置」默认关闭，打开后只把保护名单存一份到你自己的 iCloud Drive。

**中文** | [English](README_EN.md)

原生 macOS 双机监控：Air、Mini 各有 **56 点菜单栏**，资源区含分隔共 116 点；右侧再用 48 点显示直连／中转两行速度，总宽 164 点。

0.6.1 起，`直` 和 `转` 固定两行显示 Air ↔ Mini 文件同步的实际收发合计速率，当前线路用强调色。出门不能直连时显示 `直 —`，中转行显示实测速度。读数来自 Syncthing 已有本机连接统计，仅访问回环接口，不测速下载、不访问对端或改变线路；未连接、过期、刚切换或计数器重置时显示 —，取到第二个读数后更新。详情和设置中的「两机速度监测」与 `litegauge link on|off` 同源，`link status --json` 可读取两条路径。

0.5.6 起，详情面板并排显示本机和 Mini 的 CPU、内存用量／压力、交换空间与磁盘剩余容量，方便安排两机工作。Mini 数据只读 Cadence 原设备缓存，显示原采样时间；节奏与有效期由 Cadence 来源配置决定（当前 300 秒／900 秒）。暂停、断连、过期显示未知。LiteGauge 不增加远程采集器、不自动派活。

Agent 用 `litegauge resources status --json` 读取同一份对照：`local` 为本机读数，`mini` 含资源、`state`、`observedAt`、`expiresAt` 和 `intervalSeconds`。Mini 不完整时退出 1，未知字段为 `null`。执行任务仍沿原双机队列做新鲜资源检查和写入准入。

[官网下载与教程](https://litegauge.tianli.cyou) · [下载最新版](https://github.com/zengtianli/LiteGauge/releases/latest) · [报告问题](https://github.com/zengtianli/LiteGauge/issues)

<img src="docs/media/menubar.png" width="328" alt="菜单栏：Air 和 Mini 各自资源及 AI，右侧为直连和中转速度">

<img src="docs/media/panel.png" width="304" alt="轻仪详情：CPU、内存压力、交换空间与磁盘剩余容量">

以上为应用同源 AppKit 界面的示例值渲染。[24 秒界面演示](docs/media/demo.mp4) 展示同源原生界面与实时采样；不是鼠标操作录屏。

0.6.0 起固定 Air、Mini 两组，每组依次显示 CPU 百分比、内存和磁盘已用比例竖条、该机 AI「工作主会话 / 该机主会话」。界面不显示两台 AI 合计。资源各自随负载变色，AI 保持中性色。CPU 60% 黄、90% 红；内存按系统压力；磁盘超过 90% 黄、97% 起红。任一台离线、过期或缺失只清空自己的读数，显示灰色 —；会话部分覆盖只在该机显示工作数/?。点击展开两台各自完整数值、内存压力、交换空间、磁盘剩余量与 AI 摘要。安装在 Mini 时仍按 Air、Mini 排列。

- **专注三项数据。** CPU/内存每 2 秒更新，磁盘容量每 60 秒更新；展开菜单或按 ⌘R 立即刷新。
- **原生本机采集。** Swift + AppKit，无第三方运行依赖，不启动 shell 采集；资源采样离线，文件同步速度只读本机回环接口，主动检查更新时访问发行渠道，无需账号。
- **减少后台工作。** 屏幕休眠、系统睡眠或锁屏时暂停周期采集，恢复后重建 CPU 基线；可见数字、竖条填充、颜色等级、AI 比例或菜单栏外观变化时才更新位图。AI 沿同一采样节奏只读 Cadence 摘要，不新增采集器或定时器。
- **回收内存，默认全关。** 「按建议处理」或 `litegauge care reclaim --yes` 正常关闭所有未受保护的应用，清理空闲系统后台并做一次压力回收；设了内存预算后，达到预算自动关闭闲置应用。终端、Claude、Codex 及其网络通道、输入与窗口工具、系统界面始终保留，名单可改。只发正常退出请求，不强制结束。
- **也能用于脚本和 agent。** 同一个程序提供 `status --json`、按 App 节奏连续输出的 `watch`，以及查询菜单栏实例的 `app status`；GUI 与 CLI 共用采集逻辑和配色阈值。

## 下载与安装

需要 **Apple Silicon（M1 或更新）与 macOS 14 或更新版本**。当前不提供 Intel 构建，应用界面为中文。

1. 在 [Releases](https://github.com/zengtianli/LiteGauge/releases/latest) 下载对应版本的 `LiteGauge-<版本>-arm64.dmg`。
2. 打开 DMG，将 `LiteGauge.app` 拖到 `Applications`。
3. 在「应用程序」中打开 LiteGauge，在屏幕顶部菜单栏查看读数。它没有常驻主窗口，资源诊断窗口按需打开。

也可下载 ZIP，解压后将应用拖入「应用程序」。正式发行包使用 Developer ID 签名、hardened runtime，并经过 Apple 公证；公证与 SHA-256 信息随每次 Release 的 `release.json` / `SHA256SUMS` 提供。更新前在轻仪菜单按 ⌘Q 退出，然后替换旧应用。

不会自动添加登录项或更改其他监控软件。需要开机启动时，在 macOS「系统设置 → 通用 → 登录项」中添加 LiteGauge。

## 使用

详情面板新增「AI 会话」入口（0.5.3）：显示 Cadence 派生缓存里的主会话、子 agent 和状态；缺失、损坏或过期显示未知。轻仪只读本机摘要，不采集会话、不读取对话正文、不为此联网。点击请求 Cadence 打开会话页；未安装或版本尚未提供跳转入口时说明原因。

Agent 可用 `litegauge sessions status --json` 读取同一摘要，`litegauge sessions open --dry-run --json` 检查入口，`litegauge sessions open` 主动请求打开。摘要未知或入口不可用时退出 1；未知计数是 JSON `null`。

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

0.5.1 起，回收内存默认关闭所有应用，只保留受保护的。主动回收（「按建议处理」或 `litegauge care reclaim --yes`）分三步：正常关闭当前用户所有运行中的应用（含菜单栏工具，受保护的除外）；正常结束空闲的系统按需后台进程（内置白名单，只发结束信号）；用系统自带的 `memory_pressure` 做一次受控压力回收，约 1 分钟，期间读数会短暂升高、压力显示偏高。应用只收到正常退出请求，绝不强制结束；有未保存内容而停在保存提示的，结果里单列为「等待保存确认，未关闭」。

受保护的应用永不关闭：终端（Ghostty、iTerm2、Terminal、Warp、kitty、Alacritty、WezTerm）、Claude 与 Codex、它们的网络通道 Shadowrocket、Karabiner / yabai / skhd、输入法、轻仪自身、Finder / Dock / 控制中心等系统界面进程，以及任何正在运行 `claude` / `codex` 命令的应用（例如在内置终端里跑它们的编辑器）。aTrust 与 ASM 默认保护、可移除。`litegauge care protect list` 查看，`protect add <bundle id>` 添加。

内存预算默认关闭，是一个开关：菜单里勾选「内存超预算时自动处理」，或在「设置…」里打开并选预算（第一次打开取本机内存的一半），命令行是 `litegauge care budget set 5`。关闭会记住数值。设置里另有「自动关闭闲置应用」开关（命令行 `care budget keep-apps` / `close-apps`）：关掉后自动处理只清理后台并回收，不关任何应用。打开之后，菜单栏 App 在已用内存达到预算并持续 10 秒时自动回收：只关闭不在前台、且最近 10 分钟没有到过前台的未受保护应用（`care budget idle <分钟>` 可改，0 表示只保留前台应用），再做后两步。两次回收至少间隔 8 分钟；回收后仍不低于预算，说明占用来自系统层、受保护的应用或刚用过的应用，30 分钟内不再回收，建议里会列出占用构成。预算只在菜单栏 App 运行时生效，睡眠和锁屏期间暂停，回来后空闲时间重新计算。

设置里的「异常恢复」开关只管两项服务：压力持续偏高时，Shadowrocket 超过 512 MiB 重连隧道、OrbStack 超过 2 GiB 正常重启虚拟机后台，会短暂断网或中断容器；配置、镜像和数据保留。每次最多处理一个，成功后至少观察 1 小时，失败后暂停 6 小时。Shadowrocket 不会被关闭；OrbStack 在回收时按普通应用关闭。

真实点击「按建议处理」前会先确认将关闭的应用数量。顶部显示进度、已关闭的应用、等待保存确认的应用和内存前后变化，历史结果标明时间。CLI 的 `care reclaim --yes --json` 返回 `status`、`apps[]`（每个应用的 `result`：`closed`、`pending_save`、`refused`、`identity_changed`）、`pendingSaveApps`、`protectedApps` 和前后读数；什么都没做为 `no_action`，发了退出请求但没有应用退出为 `not_completed`，两者都是 `ok: false`、退出码 1，预览为 `preview`。

浏览器自 0.5.1 起按普通应用关闭，不再需要 0.4.3 的单独许可（`care browsers` 保留兼容，不再影响行为）。关闭后不再打开，不自动点击丢弃表单；下载和页面任务可能中断，浏览器自身决定下次打开如何恢复。

关闭浏览器用于释放当前占用；关闭再打开会重新加载页面并使内存回升，因此浏览器照料不再采用重启。`process restart` 仍供明确需要恢复应用的操作使用。

策略和最近 20 条处理结果仅保存在本机 `~/Library/Application Support/LiteGauge/`，不上传。明确请求 `process restart` 时保留最近两份普通会话备份，不复制 Cookie、历史数据库或密码；普通关闭不依赖会话备份。应用计账内存与系统已用内存分别记录，系统前后差值也可能受其他任务影响。退出时等待正在执行的后台处理完成（进行中的内存回收会立即停止并结束压力工具）；不强制结束进程。内存回收会让系统释放文件缓存和可回收内存，之后首次打开文件或应用可能稍慢。

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
litegauge care enable --yes        # 允许 Shadowrocket / OrbStack 的异常恢复；care disable 暂停
litegauge care status --json       # 设置读回：策略、最近检查及处理结果、版本、菜单栏实例是否在运行、此刻是否正在处理
litegauge care run --dry-run --json # 已并入 care reclaim：--yes 等同 care reclaim --yes，另含上述异常恢复
litegauge care reclaim --dry-run --json # 列出将关闭的应用、受保护的应用和将结束的空闲系统后台；不做任何操作
litegauge care reclaim --yes       # 关闭未受保护的应用，清理后台，做一次受控压力回收
litegauge care reclaim --yes --keep-apps # 不关应用，只清后台和压力回收
litegauge care reclaim --yes --only com.apple.TextEdit --keep-background # 只正常关闭指定应用，可重复 --only
litegauge care budget set 5        # 已用内存预算（GiB），达到后由菜单栏 App 自动关闭闲置应用并回收；budget off 关闭并记住数值，budget on 恢复，budget status 查看
litegauge care budget keep-apps    # 自动处理不关任何应用，只清后台并回收；budget close-apps 恢复
litegauge care budget idle 10      # 自动回收只关闭这么多分钟没到过前台的应用；0 表示只保留前台应用
litegauge care protect list        # 保护名单：内置项与用户添加项；protect add|remove <bundle id>、protect reset
litegauge process restart --pid 123 --token 123:1790000000:0 --dry-run --json # token 从诊断结果读取；改 --yes 才执行
litegauge watch --count 5 --json   # 按 App 节奏（默认每 2 秒）连续输出，每行一个 JSON（NDJSON）
litegauge watch --interval 10      # 每 10 秒一行文本，Ctrl-C 结束
litegauge app status --json        # 菜单栏实例是否在运行：pid、bundle 路径与版本
litegauge app quit --dry-run       # 查看将退出哪个实例；换成 --yes 才实际退出（与 ⌘Q 相同）
litegauge app quit --yes --pid 123 # 只退出 pid 为 123 的菜单栏实例
litegauge config status --json     # 「使用 iCloud 记住配置」开关、开关下面那句同步状态（sync_status）、可迁移的配置项（保护名单）、App 是否在运行
litegauge config export -o gauge.json # 与设置窗口「导出配置…」相同的文件；已有文件须加 --force
litegauge config import gauge.json --yes # 先备份再替换保护名单；自动处理开关、预算与阈值按每台 Mac 各自设置，不随配置迁移
litegauge config sync on --yes     # 拨动「使用 iCloud 记住配置」（默认关）；--dry-run 只看会不会变；sync off 关闭
litegauge update check --json      # 检查更新：当前版本、GitHub 正式发行、有没有新版、怎么升级；不下载、不安装
litegauge update install --dry-run --json # 升级到新版：只报会从哪个版本换到哪个版本；换成 --yes 才下载、核对签名、替换并在后台重开（没有新版时什么都不做）
litegauge --version --json
litegauge --help                   # 也可用 -h、help；任一命令或参数后加 --help / -h 也只显示帮助，不执行
```

`care reclaim`、`care protect`、`care budget` 与 `memory.wiredBytes` 自上次公开版（0.4.1）之后加入：回收与预算始于 0.5.0，关闭应用、保护名单、`--keep-apps` / `--only` / `--keep-background` 和 `budget idle` 始于 0.5.1（0.5.0 的 `care apps` 允许清单已由保护名单取代）。`care reclaim --json` 输出 `status`（`completed`、`not_completed`、`no_action`、`interrupted`，预览为 `preview`）、`apps[]`、`closedAppCount`、`pendingSaveApps`、`protectedApps`、`retainedApps`、`beforeBytes` / `afterBytes`、`compressedBeforeBytes` / `compressedAfterBytes`、`candidateCount`、`signalledCount`、`exitedCount`、`stillRunningCount`、`processes[]` 和 `pressure`（`status`、`performed`、`reachedWarn`、`seconds`、`reason`）。

`watch`、`app`、`--version --json` 与下表中的等级、百分比、错误代码字段自 0.1.2 起提供；0.1.1 只有 `status [--json]`、`--version` 和 `--help`。以下行为也自 0.1.2 起生效：`-h`、`help` 与「命令后加 `--help`」显示帮助（0.1.1 中退出 2），`litegauge` 不带参数只打印用法（0.1.1 中会走启动菜单栏 App 的路径）。

`status --json` 与 `watch --json` 的每条记录：

| 字段 | 含义 |
|---|---|
| `ok` | `errors` 为空时为 `true` |
| `sampledAt` | 采样时间，ISO 8601 |
| `cpuPercent` | 整个处理器归一化的 0–100% 使用率；尚无基线时为 `null` |
| `cpuLevel` | 同源配色等级：60% 起 `warning`，90% 起 `critical`；不可用时 `null` |
| `memory.totalBytes` / `usedBytes` / `compressedBytes` / `swapUsedBytes` | 整数字节；已用量扣除可回收缓存，交换读取失败时为 `null` |
| `memory.wiredBytes` | 内核与驱动占用（不可压缩或换出），已计入 `usedBytes`；0.5.0 起提供 |
| `memory.percent` | 内存已用比例，即菜单栏的内存竖条 |
| `memory.pressureLevel` | 系统内存压力：`normal`、`elevated`、`critical`、`unknown`；`memory.pressure` 为对应中文标签 |
| `memory.level` / `memory.displayLevel` | 压力等级对应绿、黄、红；`displayLevel` 在压力未知时为 `null`，界面显示灰色 |
| `disk.totalBytes` / `availableBytes` | 启动盘 Data 卷所在 APFS 容器的容量与可用空间 |
| `disk.usedPercent` | 磁盘已用比例，即菜单栏的磁盘竖条 |
| `disk.level` / `disk.warnAbovePercent` / `disk.criticalAtPercent` | 已用超过 90% 为 `warning`（黄），97% 起为 `critical`（红）；与菜单栏和面板同源 |
| `disk.mountPoint` / `disk.volume` | 读取的挂载点 `/System/Volumes/Data`；中文显示名 |
| `disk.sampledAt` | 磁盘读取时间；`watch` 与 App 一样每 60 秒重读一次 |
| `errors` / `errorCodes` | 面板显示的错误文字；稳定代码 `cpu_unavailable`、`memory_unavailable`、`disk_unavailable` |

缺少的读数写为 `null`，键始终存在。`app status --json` 输出 `running`、`instances[]`（`pid`、`bundlePath`、`version`、`build`、`launchedAt`、`sameBundleAsCLI`）和命令行自身所在的 `cli` 包；`app quit --json` 输出 `targets`、`stillRunning`、`dryRun`、`pid`。两者只计入带菜单栏图标的实例（已完成启动的 `.accessory` 进程）；`--ui-self-test`、`--snapshot` 等离屏验收进程不列出，也不会被退出。

退出码：`0` 成功；`1` 采集失败（`ok: false`），或 `app quit` 未能在 5 秒内退出；`2` 参数错误或缺少确认参数（原因写 stderr；带 `--json` 时 stdout 同时输出 `{"ok": false, "error": {"code": "usage", "message": …}}`）。`--json` 的失败结果在原有各键之外都带 `error.code` 与 `error.message`；`care status --json` 另有 `version`、`build`、`menuBarAppRunning`、`inProgress`、`inProgressPid`。读命令、写命令、各命令的 JSON 形状和只在窗口里的项列在 `litegauge --help`。`--help` 与 `--version` 立即返回。`litegauge` 不带参数只打印用法并退出 2，不会启动菜单栏 App；启动 App 请从「应用程序」打开，或运行 `open -g -j /Applications/LiteGauge.app`。

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
| 允许 / 暂停 Shadowrocket、OrbStack 异常恢复 | `care enable --yes` / `care disable` |
| 「按建议处理」：关闭未受保护的应用并回收 | `care reclaim --dry-run` 预览，`care reclaim --yes` 执行（`care run` 同） |
| 菜单 / 设置里的「内存超预算时自动处理」开关与预算 | `care budget on` / `care budget off`、`care budget set <GiB>` |
| 设置里的「使用 iCloud 记住配置」开关、「导出配置…」「导入配置…」 | `config sync on --yes` / `config sync off --yes`、`config export -o <文件>`、`config import <文件> --yes`；`config status` 读回（含开关下面那句同步状态） |
| 「检查更新…」「升级到新版…」 | `update check`；`update install --yes`（与窗口同一条路，先 `--dry-run` 看会做什么；没有新版时什么都不做，窗口里是「下载新版…」的情形返回 `manual_install` 与安装包地址） |
| 设置里的「自动关闭闲置应用」开关与闲置时间 | `care budget close-apps` / `care budget keep-apps`、`care budget idle <分钟>`；保护名单 `care protect list` |

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

**能监控网络、温度、风扇或各进程吗？** 支持 Air ↔ Mini 文件同步的直连／中转速度，并支持应用与进程的内存/CPU 排行和受控处理；暂不包括全机上网速度、传感器、风扇控制、磁盘读写速率或历史曲线。

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
