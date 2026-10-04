# 更新记录

## 0.3.0 · 2026-10-05

- 资源面板先给具体操作建议，移除逐个选择应用的处理流程。一次允许后，持续内存压力下自动照料异常 Shadowrocket / OrbStack；aTrust 与工作应用保留。
- 连续两次高占用、空闲时间、前台应用、CPU、完整读数与真实身份共同决定是否操作；正常虚拟机或稳定索引内存保留。成功后冷却 1 小时，失败后暂停 6 小时。
- 正常压力不扫描进程；高压力持续 90 秒后最多每 2 分钟检查一次，睡眠/锁屏重置。处理记录仅在本机保留最近 20 条，跨进程锁防重复操作，退出等待后台恢复。
- 新增 `care plan|status|enable|disable|run`，可由 agent 开启并查看结果。公开版本默认关闭，开启仅需一次允许。

## 0.2.0 · 2026-10-05

- 新增按需「资源诊断与处理」窗口：合并应用与辅助进程、内存/CPU 排行、内存压力/压缩/交换解释、可读范围与处理建议。
- 正常退出应用或受控重启，核对 PID/启动时刻/用户/路径，保留保存提示；OrbStack 正常停启虚拟机后台，Shadowrocket 重连系统隧道。动作完成后自动复查应用计账内存。
- 新 CLI：`diagnose [--sort memory|cpu] [--limit 1..50] [--json]`、`process quit|restart --pid <pid> --token <token> (--dry-run | --yes) [--json]`。无后台全机进程扫描、系统缓存清空或自动强退。
- 保持 56 pt 菜单栏、2 秒 CPU/内存采样和 60 秒磁盘采样。原生 libproc 采集，不依赖 shell 采样。

## 0.1.2 · 2026-10-01

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

0.1.0 未提供 Intel 构建、历史曲线、网络/温度监控、进程排行或自动更新。
