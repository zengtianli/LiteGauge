轻仪 LiteGauge 0.1.2：面向脚本与 agent 的命令行；菜单栏、详情面板与采样行为不变。

- `litegauge watch [--interval <秒>] [--count <次数>] [--json]`：按 App 节奏（默认每 2 秒，磁盘 60 秒）连续输出，`--json` 为每行一个 JSON。
- `litegauge app status [--json]` 查看菜单栏实例；`litegauge app quit (--dry-run | --yes) [--pid <pid>]` 与 ⌘Q 相同地退出，须显式确认。
- `status --json` 新增内存/磁盘百分比、压力与配色等级、磁盘告警阈值、挂载点和错误代码字段，原有字段保留。
- `-h`、`help` 与任一命令后的 `--help` 只显示帮助；`litegauge` 不带参数只打印用法；`--version --json` 读自所在 App 的 Info.plist。
- 面板配色的压力等级与磁盘 90% 阈值移入共享采集层，App 与命令行读同一套判断（界面渲染逐字节不变）。

- **[产品主页与安装教程](https://litegauge.tianli.cyou/)**
- 适用于 Apple Silicon，macOS 14 或更新系统；App 与 DMG 均已 Developer ID 签名并经 Apple 公证。
- 无网络请求、无第三方运行依赖；免费，MIT 开源。资源实测见 README 与 `perf/lightweight.json`（实测在 0.1.1 公证版上进行，0.1.2 的界面与采样未变，重测后更新）。SHA256SUMS 可核对下载完整性。
