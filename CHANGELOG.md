# 更新记录

## 未发布

面向脚本与 agent 的命令行；菜单栏、详情面板与采样行为不变。

- `litegauge watch [--interval <秒>] [--count <次数>] [--json]`：按 App 节奏（默认每 2 秒，磁盘 60 秒）连续输出，`--json` 为每行一个 JSON；Ctrl-C 干净结束。
- `litegauge app status [--json]`：菜单栏实例是否在运行、pid、bundle 路径与版本；`litegauge app quit (--dry-run | --yes) [--pid <pid>]`：与 ⌘Q 相同的退出，须显式确认，`--pid` 只退出指定实例。两者只计入带菜单栏图标的实例，离屏自检与渲染进程不列出、不退出。
- `status --json` 新增 `ok`、`memory.percent`、`memory.pressureLevel`、`memory.level`、`disk.usedPercent`、`disk.level`、`disk.warnAbovePercent`、`disk.mountPoint`、`errorCodes`；原有键保留，缺少的读数写为 `null`。
- 面板配色的压力等级与磁盘 90% 阈值移入共享采集层，App 与命令行读同一套判断（界面渲染逐字节不变）。
- `-h`、`help`，以及任一命令或参数后的 `--help` / `-h` 只显示帮助并退出 0（开发参数 `--benchmark`、`--snapshot`、`--ui-self-test` 后加 `--help` 不再执行对应动作）；`--help` 列出开发参数；经 `litegauge` 短命令不带参数只打印用法，不再在终端前台启动菜单栏 App。
- `--version --json`；版本号与构建号都读自所在 App 的 Info.plist，核心测试保证源码版本常量与 Info.plist 一致。

## 0.1.1 · 2026-09-28

维护版本，菜单栏、详情面板与采样行为不变。

- 新增内置离屏界面自检 `LiteGauge --ui-self-test [目录]`：不创建菜单栏图标、不开窗、不模拟输入，检查菜单结构、⌘R/⌘Q、刷新、关闭与暂停/恢复，输出截图与 JSON 结果。
- 仓库新增固定验收脚本（功能、恢复、隐私、界面）。
- 演示视频按当前版本重新录制。

## 0.1.0 · 2026-09-26

首个公开版本，适用于 Apple Silicon Mac、macOS 14 及以上。

- 固定 56 点菜单栏：CPU 百分比、内存与磁盘已用比例。
- 点击详情查看内存压力、交换空间、磁盘剩余容量。
- CPU/内存每 2 秒刷新，磁盘每 60 秒；菜单内 ⌘R 立即刷新。
- 系统或屏幕睡眠、锁屏时暂停采样，恢复后重新建立 CPU 基线。
- 同源命令行 `status --json`，无第三方运行依赖和网络请求。
- Developer ID 签名、Apple 公证，提供 ZIP 与 DMG 下载。

资源占用及测量范围见 [实测证据](perf/lightweight.json)。

本版不提供 Intel 构建、历史曲线、网络/温度监控、进程排行或自动更新。
