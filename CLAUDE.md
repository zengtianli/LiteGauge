# LiteGauge · 极简菜单栏监控

自用 macOS 原生 App，仅显示 CPU、内存、启动磁盘容量。用户明确选择极简原型；当前不公开发布、不做产品推广页，也不替换 Stats 的登录项。

- 菜单栏必须紧凑：2026-09-26 用户以 Stats 截图纠正，禁止横排 CPU/MEM/SSD 全部标签与百分比。固定 56 pt：CPU 上下两行，内存/磁盘各一条竖向填充条；详细数值放点击面板。

- 源码 `Sources/`；共享采集逻辑同时供 App 与 `LiteGauge status --json` 使用。
- 构建 `bash build.sh`，产物 `build/LiteGauge.app`；测试 `bash build.sh --test-only`。
- 实测 `perf/lightweight.json`；当前状态 `handoffs/current.md`。
- GUI 用 AppKit，无第三方运行依赖、无 shell 采集、无联网。CPU/内存合并每 2 秒采样，磁盘容量每 60 秒；锁屏/睡眠停采，唤醒重置 CPU 基线。
- 保持 CPU 计数器溢出、内存缓存与 APFS 容量口径正确；读取失败显示不可用，不把旧数据装作新数据。
- 不添加全局快捷键；标准菜单键盘操作、⌘R 刷新、⌘Q 退出。
- 装到 /Applications、替换/退出 Stats、开机启动须按当前会话授权；后台验证只启动本项目测试实例，不抢焦点。
