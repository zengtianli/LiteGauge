# LiteGauge · 轻仪

**中文** | [English](README_EN.md)

自用的原生 macOS 菜单栏小工具，只看 CPU、内存和启动磁盘。菜单栏固定 **56 点**：CPU 标签与百分比上下排列，右侧依次为内存、磁盘的竖向占用条。点击可看完整数值、内存压力与交换空间。

CPU/内存每 2 秒更新，磁盘容量每 60 秒更新；展开菜单或按 ⌘R 立即刷新。开机后首次 CPU 结果需要约 1 秒采样。屏幕休眠、系统睡眠或锁屏时暂停周期采集，恢复后重建 CPU 基线。

使用 Apple 系统框架，无第三方运行依赖、不联网、不启动 shell 采集。首版不包含进程排行、网络、传感器、风扇控制和历史曲线；菜单提供系统活动监视器入口。

## 本地运行

- 构建：`bash build.sh`，输出 `build/LiteGauge.app`，Apple Silicon / macOS 14+。
- 双击 `build/LiteGauge.app` 即可运行。菜单内 ⌘R 刷新、⌘Q 退出，也可用方向键和回车选择菜单命令。
- 经确认安装后：`bash scripts/install.sh`，安装到 `/Applications/LiteGauge.app`，同时提供 `~/.local/bin/litegauge`。
- 程序只在菜单栏显示；不自动添加登录项，不修改 Stats 的配置。
- 本地构建采用 ad-hoc 签名，尚未公证，不作为对外发行包。

## 命令行

```sh
build/LiteGauge.app/Contents/MacOS/LiteGauge status
build/LiteGauge.app/Contents/MacOS/LiteGauge status --json
# 安装后
litegauge status --json
```

CLI 与 GUI 使用 `Sources/Metrics.swift` 的同一采集逻辑。JSON 字段：`cpuPercent`、`memory`、`disk`、`sampledAt`、`errors`；字节值为整数，时间为 ISO 8601。CPU 为整个处理器归一化后的使用率，范围 0–100%；首次快照无差分基线时为 null。

退出码：0 成功，1 采集失败，2 参数错误。CLI 为计算真实 CPU 差分需要约 1 秒。`--help` / `--version` 无采集等待。

## 数值口径

- 内存以 GiB 显示，16 GiB 内存显示为 16.0 GiB。已用内存扣除可回收文件缓存和可清除页；“压力”取系统压力级别，不能单看使用率判断内存不足。
- 磁盘以十进制 GB 显示。只读取启动盘 Data 卷所处 APFS 容器的总容量与当前可用块，不把共享容量的多个卷相加；未加回可清除空间，所以可能不同于 Finder 的“可用空间”。
- 磁盘百分比与竖条均表示已用比例；磁盘详情显示剩余空间。
- 资源实测证据在 `perf/lightweight.json`；`footprint_mb` 沿共享测量脚本使用 MiB，README 展示 MB 时换算为十进制。

<!-- lightweight:start -->
当前构建的性能测量进行中，结果见 `perf/lightweight.json`。
<!-- lightweight:end -->

## 验证与维护

`bash build.sh --test-only` 覆盖 CPU 差分/计数溢出、内存缓存扣除/下溢、磁盘缓存/手动刷新、锁屏与休眠叠加状态、真实系统读取。通过隔离变异验证，错误的 CPU 计算会被测试拒绝。

`LiteGauge --snapshot <path.png>` 输出实际面板的离屏渲染，用于检查排版，不会激活窗口。当前状态与验证限制见 `handoffs/current.md`。

应用图标由 OpenAI 内置 image_gen 生成；来源、提示词与确定性图标包装参数保存在 `icon/provenance.json`。Seedream 服务本次 TLS 连接失败，没有生成可用图片。
