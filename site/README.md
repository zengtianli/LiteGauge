# LiteGauge 产品主页

独立静态站，默认亮色、响应式、无 JavaScript（含内联脚本）或第三方网页依赖。正式图标来自 `icon/AppIcon.png`。

页面按 Lintel 推广页规范排成唯一 `main` 里的七个 `section`，顺序固定：首屏 `hero` → 能力 `#features` → 资源 `#light` → 教程 `#install` → 演示 `#demo` → 帮助 `#help` → 获取 `#get`。改版时保持这些 id 和先后顺序，教程在演示之前。

```sh
python3 scripts/build-site.py
```

输出 `dist/site/`，每次整目录重建，末尾写 `site-manifest.json`（目录内全部公开文件的路径、SHA-256、字节数）。需要 Python 3 与 PyYAML，不联网；资源数字和 `facts.json` 由 `~/Apps/apps-portal/site/` 的共享 `perf_block.py`、`product_facts.py` 渲染，缺少时构建失败，不在本仓另写一套格式化。

发布前自查（只读）：

```sh
~/Dev/.venv/bin/python ~/Apps/lintel/engine/lintel.py site check --site apps --product litegauge --bundle dist/site --json
```

- 发布事实：默认读已公开发行的记录 `release/latest.json`（`project.yaml` 的 `sop.release`）；预览尚未公开的包才传 `--release build/release/release.json`。版本、ZIP 大小、SHA-256、最低系统与公证状态均从该文件读取。
- 安装包：页面的下载链接指向站内 `downloads/<ZIP>`，与 GitHub Release 是同一份文件。构建在发行记录同目录和 `build/release/` 找这个 ZIP（或用 `--archive` 指定），核对字节数与 SHA-256 后复制进站点；找不到或对不上即失败，不自动下载。
- 性能事实：`perf/lightweight.json`。实测版本与发行版本一致时还要求下载包字节数一致；不一致时页面自动标明这是哪一版的历史实测、不代表当前公开下载的版本，并写出当前下载包大小和未测项及原因。完整冷启动未测时照写未测与原因。
- 真实素材：`docs/media/panel.png`、`diagnosis.png`、`demo.mp4`、`demo-poster.jpg`、`demo.zh.vtt`。构建缺少任意一项即失败；只做本地排版时可显式传 `--allow-missing-media`，该预览产物不得部署。菜单栏条 `menubar.png` 高 36 px，低于规范的截图最小边 128 px，不单独上页，由演示视频放大展示。
- 素材版本：录制版本取 `docs/media/manifest.json` 的 `version`；与发行版本不同时，首屏截图说明和演示区会写明录自哪一版、与当前公开下载不是同一版本。
- 媒体来源、录制版本与覆盖范围由 `docs/media/` 中的制作记录维护；界面截图和录像不能用合成产品界面替代。

页面不自动播放视频；原生播放控件、中文字幕和视频下载入口均保留。首次打开指引参考 Apple 官方文档：<https://support.apple.com/zh-cn/102445>。
