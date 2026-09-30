轻仪 LiteGauge 0.1.1：维护版本，菜单栏、详情面板与采样行为不变。

- 新增内置离屏界面自检 `LiteGauge --ui-self-test [目录]`：不创建菜单栏图标、不开窗、不模拟输入，检查菜单结构、⌘R/⌘Q 快捷键、刷新、关闭与暂停/恢复，并输出截图与 JSON 结果。
- 仓库新增固定验收脚本（功能、恢复、隐私、界面），便于每次发布前自动复核。
- 演示视频按当前版本重新录制。

- **[产品主页与安装教程](https://litegauge.tianli.cyou/)**
- 适用于 Apple Silicon，macOS 14 或更新系统；App 与 DMG 均已 Developer ID 签名并经 Apple 公证。
- 无网络请求、无第三方运行依赖；免费，MIT 开源。资源实测见 README 与 `perf/lightweight.json`（2026-09-29 在已安装的 0.1.1 公证版上重测）。SHA256SUMS 可核对下载完整性。
