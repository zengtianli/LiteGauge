# LiteGauge · 轻仪

**中文** | [English](README_EN.md)

只占 **56 点菜单栏**的原生 macOS 系统监控：CPU、内存、启动磁盘，一眼看完。

[官网下载与教程](https://litegauge.tianli.cyou) · [下载最新版](https://github.com/zengtianli/LiteGauge/releases/latest) · [报告问题](https://github.com/zengtianli/LiteGauge/issues)

<img src="docs/media/menubar.png" width="112" alt="菜单栏：CPU 和内存、磁盘竖条">

<img src="docs/media/panel.png" width="304" alt="轻仪详情：CPU、内存压力、交换空间与磁盘剩余容量">

以上为应用同源 AppKit 界面的示例值渲染。[24 秒界面演示](docs/media/demo.mp4) 展示同源原生界面与实时采样；不是鼠标操作录屏。

CPU 标签与百分比上下排列，右侧两根竖条依次表示内存、磁盘的已用比例。点击展开完整数值、内存压力、交换空间和磁盘剩余量。

- **专注三项数据。** CPU/内存每 2 秒更新，磁盘容量每 60 秒更新；展开菜单或按 ⌘R 立即刷新。
- **原生且离线。** Swift + AppKit，无第三方运行依赖、不联网、不启动 shell 采集；无需账号。
- **减少后台工作。** 屏幕休眠、系统睡眠或锁屏时暂停周期采集，恢复后重建 CPU 基线；可见整数变化时才更新菜单栏。
- **也能用于脚本。** 同一个程序提供 `status --json`，GUI 与 CLI 共用采集逻辑。

## 下载与安装

需要 **Apple Silicon（M1 或更新）与 macOS 14 或更新版本**。当前不提供 Intel 构建，应用界面为中文。

1. 在 [Releases](https://github.com/zengtianli/LiteGauge/releases/latest) 下载 `LiteGauge-0.1.0-arm64.dmg`。
2. 打开 DMG，将 `LiteGauge.app` 拖到 `Applications`。
3. 在「应用程序」中打开 LiteGauge，在屏幕顶部菜单栏查看读数。它没有 Dock 图标或普通主窗口。

也可下载 ZIP，解压后将应用拖入「应用程序」。正式发行包使用 Developer ID 签名、hardened runtime，并经过 Apple 公证；公证与 SHA-256 信息随每次 Release 的 `release.json` / `SHA256SUMS` 提供。更新前在轻仪菜单按 ⌘Q 退出，然后替换旧应用。

不会自动添加登录项或更改其他监控软件。需要开机启动时，在 macOS「系统设置 → 通用 → 登录项」中添加 LiteGauge。

## 使用

| 操作 | 结果 |
|---|---|
| 点击菜单栏 CPU / 竖条 | 展开 CPU、内存、磁盘详情 |
| 菜单内 ⌘R | 立即刷新 |
| 菜单内 ⌘Q | 退出 LiteGauge |
| 「打开活动监视器」 | 进一步查看进程占用 |

原生菜单支持方向键和回车。没有全局快捷键。启动后首次 CPU 数值需要约 1 秒采样。

## 命令行

安装应用后即可使用，无需另装运行环境：

```sh
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status --json
/Applications/LiteGauge.app/Contents/MacOS/LiteGauge --help
```

可选地添加简短命令（如果已有同名文件，请先检查）：

```sh
mkdir -p "$HOME/.local/bin"
ln -s /Applications/LiteGauge.app/Contents/MacOS/LiteGauge "$HOME/.local/bin/litegauge"
# 将 ~/.local/bin 加入 PATH 后：
litegauge status --json
```

JSON 字段为 `cpuPercent`、`memory`、`disk`、`sampledAt`、`errors`。字节值为整数，时间为 ISO 8601；CPU 为整个处理器归一化的 0–100% 使用率。缺少有效采样时，相关数值为空；错误会写入 `errors`。

退出码：`0` 成功，`1` 采集失败，`2` 参数错误。CLI 的 CPU 差分需要约 1 秒采样，`--help` 和 `--version` 立即返回。

<!-- lightweight:start -->
## 资源占用

| 安装包 | 空闲内存 | 空闲 CPU | 进程内首个 CPU 数值（单次） |
|---|---|---|---|
| **1.6 MB**（装好后 1.8 MB） | **14.7 MB** | **0.86%** | **1.3 s** |

原生 AppKit；无第三方运行依赖和网络请求；CPU/内存共用2秒采样器，磁盘容量缓存60秒；数值变化时才重绘。

<sub>v0.1.0 · Mac16,12 / Apple M4 / macOS 27.2 · 公证发行版；菜单收起，CPU/内存每2秒、磁盘每60秒；启动后静置45秒，M4/16 GiB 当前日常负载 · 2026-09-26。数字来自所列设备实测，版本更新后重新测量。内存口径为 phys_footprint；CPU 为 60 秒采样窗内 CPU 时间 ÷ 墙钟；大小按十进制 MB。原始数据见 [perf/lightweight.json](perf/lightweight.json)。</sub>
<!-- lightweight:end -->

这组数据来自所列设备和刷新设置，并不保证每台 Mac 都相同。首个 CPU 数值的耗时包含采样等待，不等于完整冷启动耗时。

## 常见问题

**为什么内存使用率与其他工具不同？** 内存以 GiB 显示；已用量扣除可回收文件缓存和可清除页。内存压力读取系统级别，不能仅凭使用率判断内存不足。

**为什么磁盘剩余量与 Finder 不同？** LiteGauge 读取启动盘 Data 卷所在 APFS 容器的总容量和当前可用块，不累加共享容量的多个卷，也不加回可清除空间。磁盘以十进制 GB 显示；竖条为已用比例，详情为剩余容量。

**能监控网络、温度、风扇或各进程吗？** 当前版本只监控 CPU、内存和启动磁盘容量；没有网络速度、传感器、风扇控制、磁盘读写速率或历史曲线。需要进程详情时，可从菜单打开系统活动监视器。

**可以与 Stats 一起安装吗？** 可以，两者使用不同名称和应用标识。并行运行的资源占用会相加；保留两款、平时只运行一款即可。

**找不到菜单栏图标怎么办？** 确认应用已启动；检查菜单栏管理工具或刘海屏是否隐藏了该项目。尝试退出其他占据菜单栏的项目后再查看。

**macOS 提示无法打开怎么办？** 先确认下载自本仓库的 Release，并对照 `SHA256SUMS`。正式包已签名与公证；若仍报错，请在 Issue 附上完整提示、macOS 版本、芯片型号和应用版本。请勿关闭 Gatekeeper。

**如何卸载？** 在轻仪菜单退出，把 `LiteGauge.app` 移到废纸篓；若手动添加了 CLI 软链或登录项，再移除相应入口。程序不保存监控历史。

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
bash scripts/install.sh  # 首次安装到 /Applications，并添加 ~/.local/bin/litegauge
```

测试覆盖 CPU 差分与溢出、内存扣除与下溢、磁盘缓存与刷新、睡眠/锁屏叠加状态及真实系统读取。`Sources/Metrics.swift` 为 GUI/CLI 共用采集层，`Sources/App.swift` 负责菜单栏与详情，`Sources/main.swift` 处理入口。

发布维护者可使用 `scripts/package-release.sh` 构建签名、公证的 ZIP 与 DMG。通过环境变量提供 `CODE_SIGN_IDENTITY`，并配置 `NOTARY_PROFILE`，或 `ASC_KEY_ID`、`ASC_ISSUER_ID` 和 `NOTARY_KEY_FILE`。脚本输出 `build/release/release.json` 与 `SHA256SUMS`；凭据不得提交。

## 许可与反馈

采用 [MIT License](LICENSE)。这是独立实现的极简工具，使用 Apple 系统 API，不是 Stats 的分支。图标由 OpenAI image generation 生成，来源信息保存在 `icon/provenance.json`。

欢迎提交 [Issue](https://github.com/zengtianli/LiteGauge/issues) 或改进。报错请提供版本、系统、芯片、复现步骤和预期行为；截图与 CLI 输出提交前请检查个人信息。
