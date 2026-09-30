# LiteGauge · 极简菜单栏监控

macOS 原生极简 App，仅显示 CPU、内存、启动磁盘容量。用户于 2026-09-26 授权公开 GitHub、发布下载版本、制作产品主页与应用目录推广；保持紧凑范围，不替换 Stats 的登录项。

- 菜单栏必须紧凑：2026-09-26 用户以 Stats 截图纠正，禁止横排 CPU/MEM/SSD 全部标签与百分比。固定 56 pt：CPU 上下两行，内存/磁盘各一条竖向填充条；详细数值放点击面板。

- 源码 `Sources/`；共享采集层 `Metrics.swift`（含面板配色等级、磁盘 90% 阈值、采样节奏常量）同时供 App 与命令行使用，App 不另写判断。命令解析与输出在 `CLI.swift`（版本常量 `version` 也在这里，须与 Info.plist 一致，核心测试检查），`main.swift` 只分派。命令行面向 agent：`litegauge status|watch|app status|app quit`，登记于 project.yaml `sop.cli`；`litegauge` 不带参数只打印用法，不启动菜单栏 App。
- 构建 `bash build.sh`，产物 `build/LiteGauge.app`；测试 `bash build.sh --test-only`。
- 实测 `perf/lightweight.json`；当前状态 `handoffs/current.md`。
- 对外入口：`https://github.com/zengtianli/LiteGauge`、`https://litegauge.tianli.cyou`；中英文 README、产品主页、目录卡片消费同一实测证据。下载包在 `build/release/`，公开截图与视频在 `docs/media/`。
- 视频若由同源 AppKit 离屏渲染生成，明确标注覆盖范围，不能称为用户点击的实机屏幕录制。
- GUI 用 AppKit，无第三方运行依赖、无 shell 采集、无联网。CPU/内存合并每 2 秒采样，磁盘容量每 60 秒；锁屏/睡眠停采，唤醒重置 CPU 基线。
- 保持 CPU 计数器溢出、内存缓存与 APFS 容量口径正确；读取失败显示不可用，不把旧数据装作新数据。
- 不添加全局快捷键；标准菜单键盘操作、⌘R 刷新、⌘Q 退出。
- 装到 /Applications、替换/退出 Stats、开机启动须按当前会话授权；后台验证只启动本项目测试实例，不抢焦点。
