轻仪 LiteGauge 的首个公开版本：用 **56 点菜单栏**查看 CPU、内存与磁盘。

- **[产品主页与安装教程](https://litegauge.tianli.cyou/)**
- 适用于 Apple Silicon，macOS 14 或更新系统。
- ZIP 解压后将 LiteGauge.app 拖入“应用程序”；DMG 打开后拖入 Applications。
- App 与 DMG 均已完成 Developer ID 签名和 Apple 公证；无需关闭系统安全设置。
- 启动后只显示菜单栏指示器，不打开主窗口，不自动加入登录项。
- 无网络请求、无第三方运行依赖；免费，MIT 开源。

CPU/内存每 2 秒刷新，磁盘每 60 秒。菜单内可立即刷新或打开活动监视器。提供同源 CLI：`/Applications/LiteGauge.app/Contents/MacOS/LiteGauge status --json`。

资源实测、测量环境和范围见仓库 README 与 `perf/lightweight.json`。SHA256SUMS 可核对下载完整性。本版不含 Intel 构建、传感器、进程排行或自动更新。
