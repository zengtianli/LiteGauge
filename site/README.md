# LiteGauge 产品主页

独立静态站，默认亮色、响应式、无 JavaScript 或第三方网页依赖。正式图标来自 `icon/AppIcon.png`。

```sh
python3 scripts/build-site.py
```

输出 `dist/site/`。需要 Python 3；构建不依赖其他仓库或网络。

- 发布事实：`build/release/release.json`。版本、下载地址、ZIP 大小、SHA-256、最低系统与公证状态均从该文件读取；本地 ZIP 存在时会重验文件大小与哈希。
- 性能事实：`perf/lightweight.json`。必须与发布版本、下载包字节数一致。内存的 `footprint_mb` 是 MiB，页面按十进制 MB 换算。首次有效 CPU 读数与完整冷启动明确区分。
- 真实素材：`docs/media/menubar.png`、`panel.png`、`demo.mp4`、`demo-poster.jpg`、`demo.zh.vtt`。构建缺少任意一项即失败；只做本地排版时可显式传 `--allow-missing-media`，该预览产物不得部署。
- 媒体来源、录制版本与覆盖范围由 `docs/media/` 中的制作记录维护；界面截图和录像不能用合成产品界面替代。

页面不自动播放视频；原生播放控件、中文字幕和视频下载入口均保留。首次打开指引参考 Apple 官方文档：<https://support.apple.com/zh-cn/102445>。
