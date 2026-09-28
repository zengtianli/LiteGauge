# 轻仪 LiteGauge · 当前交付

2026-09-26。用户要求极简 CPU/内存/磁盘监控、紧凑菜单栏、改名且保留 Stats；随后授权 GitHub 与 product-homepage 推广。

## 当前入口

- 官网：<https://litegauge.tianli.cyou/>
- 源码：<https://github.com/zengtianli/LiteGauge>，MIT，中文 README / 对应英文 README。
- 正式版：<https://github.com/zengtianli/LiteGauge/releases/tag/v0.1.0>
- 目录：<https://apps.tianli.cyou/mac.html>，轻仪卡片跳独立官网。
- 安装 /Applications/LiteGauge.app，普通模式运行；Stats 的安装、运行与登录项保留。
- 源目录 ~/Apps/litegauge（2026-09-27 由 tlstats 改名），登记 id/family 为 litegauge。

## 发行与验证

0.1.0 (1)，bundle cyou.tianli.litegauge，Apple Silicon / macOS 14+，中文界面。ZIP 1,626,948 bytes，DMG 2,129,632 bytes；均 Developer ID 签名、Apple 公证 Accepted、票据已装订。最终可执行 SHA256：5f86b96672c3325f2d2ca2e194e5b98741c0abe608cf8ab3961acd45d17beb95。

perf/build-receipt.json 包围实际 bash scripts/package-release.sh 构建生成；安装版与 receipt 一致。发布元数据见 release/latest.json。独立解包、Gatekeeper、公证票据、DMG 内容、CLI JSON/错误码、干净源码副本构建已验；14 项核心测试和 GitHub CI 通过。未在真实 macOS 14 设备运行。

注意 bash build.sh 会覆盖 build/LiteGauge.app 为 ad-hoc 本机包。app_sop build-receipt 会真正执行传入命令；发行包必须传实际签名公证构建，不能给旧包填来源。

## 实测

M4 / 16 GiB，macOS 27.2，最终公证版菜单收起，启动后静置 45 秒，CPU 采样 60 秒，footprint 在窗口后取 3 次。

- ZIP 1.6 MB，安装约 1.8 MB。
- phys_footprint 14.0 MiB，即十进制 14.7 MB。
- CPU 平均 0.86%，100% 为一个核心。
- 同源码版本进程初始化至首个 CPU 差分单次约 1.3 秒，含 1 秒采样等待；完整冷启动多次统计未测。

唯一事实源 perf/lightweight.json；官网、README、目录卡片均读取。早期与 Stats 的不同刷新设置样本不作为公开竞品基准。共享 perf_block 的 MiB/MB 与 CPU 精度修复通过门户 76 项测试、20 个子测试，由工作区自动同步提交 203a6b5 收录。

## 界面与素材

菜单栏 56 pt：CPU 上下两行，内存/磁盘各一根竖条。CPU/内存 2 秒、磁盘 60 秒；睡眠/锁屏暂停。bash scripts/capture-media.sh 使用正式 StatusRenderer、SummaryView、MetricsSampler 离屏制作，不创建窗口或合成输入。

截图为固定示例值；24 秒视频是实时采样的同源原生界面演示，分 CPU/内存/磁盘三段，有中文烧录字幕、VTT、海报。页面明确不是鼠标操作录屏。原片/样本在忽略入库的 build/media/，公开产物/记录在 docs/media/。浏览器已确认线上视频播放至 24 秒、readyState 4、无错误，HTTP Range 206。

原生 CUA 获取 LiteGauge 仍超时，未自动验证真实菜单点击、键盘动作或真实睡眠/唤醒。逻辑测试和离屏界面不证明这些动作已测。

## 发布维护

- App：scripts/package-release.sh（凭据走环境和标准私钥路径）→ 实测 → README 数字块 → 提交 → GitHub Release。
- 官网：python3 scripts/build-site.py → dist/site/；公开元数据可用 --release release/latest.json。scripts/deploy-site.sh 上传临时目录后切换，保留 previous。
- scripts/verify-site.py 逐文件核线上内容、ZIP/DMG SHA256、视频 206；浏览器播放独立验证。
- 首次 DNS / 8443 Origin Rule / 受管 nginx / 分类与部署登记已完成。CF 写接口曾截断响应，回读确认生效后续跑后续步骤，没有重复创建。
- 本机代理偶发截断 urllib 响应；verifier 用系统 curl 有界重试只读 GET，完整哈希检查仍保留。
- 门户沿 apps-portal/site/deploy.sh；上线前 VPS 备份 /var/backups/litegauge-launch-20260926-153646/。

## 未达到的目标

初始 CPU 预算 0.3% 仍未达到，project.yaml 保留目标，不能为标绿抬高预算。保持两秒采样没有发现足以保证达到 0.3% 的低风险改动。

perf/raw/sample.txt 是旧 TLStats 横排标题版本，不能据它断言最终 bitmap 版热点或归因 accessibility。当前 image/AX 更新已有整数值去重，详情只在菜单展开时更新。后续可独立测按实际条形像素高度去重图片；CPU 数字仍常变，收益未知，不在推广发布中临时改渲染方案。

机器 SOP 的性能预算仍需处理；不宣称全部轻量化目标已达成。

## 2026-09-27 装机核对（Chapter 授权装机）

- 用户决定本次接受空闲 CPU 0.86% 超出 0.3% 目标，不修。会话中途试做的菜单栏原地重绘改动已撤回，未提交、未测定收益；如以后要优化，热点线索是每 2 秒换 NSImage 触发状态项布局与 3 块屏幕 replicant 快照（sample 所见）。
- 源码自 26b0fe1 起未变，/Applications/LiteGauge.app 已是当前版本的公证发行版：可执行 SHA256 与 build-receipt 一致，codesign/spctl（Notarized Developer ID）/stapler 通过，安装包 AppIcon.icns 与 icon/AppIcon.icns 字节一致。因此未重装，没有退出或替换正在运行的实例（PID 30165），CLI 软链与登录项未动。
- installed_icon 待用户在 Chapter 确认 Dock/Finder 实际显示；未代写通过。当前 installed_icon 绑定 cb805e27…e40e。
- build/LiteGauge.app 已按 HEAD 重建为本机 ad-hoc 包（忽略入库）。

## 2026-09-28 工程质量实际验收

- functionality / recovery / privacy 已对已安装公证版（可执行 SHA256 5f86b966…）真实执行，原件在 perf/acceptance/{functionality,recovery,privacy}.txt，已写入 perf/delivery-evidence.json（business 绑定 97cce2d7…8740）。Chapter monitor 回读：这三项已不在缺项 coverage 中。
- perf/delivery-evidence.json 同时含 Chapter 记录的本人 installed_icon 确认（及 perf/installed-icon-review.json），两者都未由本会话提交，留工作树。
- native_ui 未过：本会话没有 Computer Use，按硬约束不能合成点击/按键；打开状态栏菜单会接管用户的鼠标键盘输入。需在有 Computer Use 的会话里点状态项、看面板、⌘R 刷新、Esc 关闭、⌘Q 前停下，再写 method ui_automation 或由本人手测后写 manual。

## 2026-09-28 资源与性能 input-binding

- 成因：2026-09-27 23:46 监测看到了我临时（未提交、已撤回）的渲染实验，app_sop 记下 perf/media 的 input-binding 失效；该标记在证据文件本身更新前不会自动清除，即使源码已回到发布版。
- media：核对 docs/media/manifest.json 的 sources_sha256 与当前源码逐字节一致、26b0fe1 后无源码变更，写入 manifest 的 reverified 记录（manifest 不发布到官网）。随后 `app_sop.py run --stage media --stage promo --check-only` 通过，media/promo 均 ok。
- perf：未处理。perf/lightweight.json 被官网直接链接，只为清标记改它会让线上副本过期；需要真实重测。重测受空闲门限制（接电源、HID 空闲 ≥600 s）；本会话用户在用机（HID 空闲约 2 s），未采样。条目带 auto=measure，定时 monitor --fix-changed 在空闲时会自动重测已安装版；或空闲时手动 `~/Dev/.venv/bin/python ~/Apps/chapter/engine/app_sop.py run --app litegauge --stage perf --now`。重测后官网的 lightweight.json 与数字需按既有授权重新部署。

## 2026-09-28 图标审阅 icon_review

- 模型逐张查看 1024 原图与 icns 实际 16/32/64/128/256 px（深浅四种底色，16/32 另放大 6 倍），记录与图片在 perf/acceptance/icon-review*.{json,png}；已写 delivery-evidence icon_review（icon 绑定 86e77dbb…9850），monitor 回读后不再列为缺项。
- 观察：32 px 起三柱清晰，16 px 可辨；浅底小尺寸瓷砖边缘对比弱。provenance 显示为 Seedream 失败后的 OpenAI 生图兜底，与共享默认提供方不同，如需统一可以后用 Seedream 重做（不在本次范围）。
- perf/delivery-evidence.json 混有 Chapter 写入的 installed_icon 记录，仍未提交，留工作树。

## 2026-09-28 产品材料：主页与演示播放

- 新增 scripts/page-probe.swift：WebKit 离屏检查线上页（屏幕外无边框窗口、忽略鼠标、.prohibited 策略，不抢焦点）。纯无窗口 WKWebView 不加载 <video>（readyState 0），必须挂在窗口里。
- 实测线上 https://litegauge.tianli.cyou/：1280 桌面与 390 iPhone UA 整页截图逐段目视正常、无横向溢出；页面内 video 静音播放至 24/24 s、ended、无错误，三段字幕按时切换。记录 perf/acceptance/homepage-media.json（截图 png 仅本机，被 .git/info/exclude 忽略）。已写 delivery-evidence homepage_desktop/homepage_mobile/media_playback；monitor 回读 coverage 只剩 native_ui。
- 相邻问题（未修，不在本仓库）：demo.zh.vtt 以 application/octet-stream 下发，WebKit 能读，Firefox 等可能要求 text/vtt；应在 VPS nginx 的 MIME 映射补 vtt。页脚 AppIcon.png 708 KB 用于 44/88 px 显示，可在下次站点构建时出小尺寸图。
- 00:11 另一写入方（Chapter 自动验收）在 perf/acceptance/ 生成 homepage_*/media_playback/icon_review 的 .json/.log/.png，并把 delivery-evidence 对应四项改指向它们；本会话未改动、未提交这些文件。本会话的 homepage-media.json、icon-review.json 仍保留为独立原件。

## 2026-09-28 固定验收脚本（sop.accept）

- App 新增 `LiteGauge --ui-self-test [目录]`（Sources/App.swift 扩展 + main.swift 入口）：不建状态项、不开窗、不合成输入；离屏构建真实菜单/面板/指示器，直接调用 menuWillOpen、「立即刷新」动作（NSApp.sendAction）、menuDidClose、暂停/恢复，断言 12 项并存截图。反向验证：把刷新改成不强制读磁盘时 refresh_updates_cpu_and_disk 失败、退出 1。
- scripts/accept/{functionality,recovery,privacy,native_ui}.sh 登记于 project.yaml sop.accept（只提交了 accept 块；他人对 project.yaml 的整文件缩进改动仍未提交）。四个脚本经 scripts/accept/_build.sh 加锁构建当前源码一次、各用临时副本，因为 app_sop accept 并行运行，直接共用 build/LiteGauge.app 会互相覆盖签名。
- `app_sop.py accept --app litegauge --all`：除 installed_icon（本人确认）外 8 项 passed；monitor coverage 为空。`--benchmark` 测试实例 GUI 启动冒烟正常（首个 CPU 读数约 1.07 s，随即结束）。
- 代价：源码变了，ship 阶段显示当前源码与装机/发布 0.1.0 不同，perf 的 input-binding 再次失效（被测装机版其实未变）。需要发 0.1.1（公证）+ 装机后重测；均需授权。media 已在 manifest 记 reverified（绘制代码未改）。
- 收尾回读：coverage 为空（media_playback 在 manifest 变更后重跑 accept 通过）。剩余 stale：perf input-binding（需重测）、media「录制后界面源码又改了 1 次」（按提交时间判断，需 capture-media.sh 重录并重新部署官网）、ship 三项（需发版+装机；「未提交改动」来自他人未提交的 project.yaml 缩进）。

## 2026-09-28 重录素材

- `bash scripts/capture-media.sh`（离屏、同源渲染）重录：menubar.png / panel.png 与旧版逐字节相同（渲染未变），demo.mp4 / demo-poster.jpg / manifest 按当前源码与实时采样重新生成，提交 c8e0f99。check-only 回读 media 阶段 ok，media_playback accept 通过，coverage 为空。
- 线上官网仍是旧视频（线上 sha 462f46aa… = 旧版；本地新版 dbe5c61e…）；需按授权 `python3 scripts/build-site.py && bash scripts/deploy-site.sh` 后线上一致。
- 仍需授权：装机（build-receipt stale）、发版 0.1.1（带 --ui-self-test）、装机后空闲重测 perf。

## 2026-09-28 维护：build-receipt / 发版前置

- 仅剩 ship.build-receipt（需装机）与 release（本人决定）；本轮禁止装机/发版，未做。验收 coverage 为空，perf input-binding 待装机后空闲重测。
- 0.1.0 之后唯一源码变更：0337de4（`--ui-self-test` 离屏自检 + 固定验收脚本），用户可见行为不变。
- 若发 0.1.1：版本号在 Info.plist（CFBundleShortVersionString 0.1.0、CFBundleVersion 1）、Sources/main.swift `let version`、scripts/capture-media.sh 的 manifest version；release-notes 草稿一句即可：「新增内置离屏界面自检 `LiteGauge --ui-self-test`，用于自动验收；菜单栏、面板与采样行为不变。」随后 `bash scripts/package-release.sh` → 装机 → `app_sop.py run --app litegauge --stage ship --check-only` → 空闲时 `--stage perf --now` → 官网 build/deploy（同时带上已重录的视频）。
- 若不发版只装自用：`bash build.sh` 后替换 /Applications（需先退出运行中的轻仪），再按 app_sop build-receipt 以实际构建命令生成 receipt；此时装机版与公开发布版不同，需在 receipt 中如实标注。

## 2026-09-28 发布 0.1.1 (2) 并装机（本人长期授权）

- 版本：Info.plist 0.1.1 / build 2、main.swift、capture-media 清单版本、README 下载文件名、release-notes（3d47e2a）。`app_sop.py build-receipt ... --build-command "bash scripts/package-release.sh"` 包裹签名公证打包：App 与 DMG 公证 Accepted（473cf45c…、66bcc693…），receipt commit 3d47e2a、dirty=false，可执行 e5dca53e…。
- 装机：TERM 退出旧实例（PID 30165）→ 旧包移到 ~/.Trash/litegauge-0.1.0-20260928/ → ditto 新包 → `open -g -j` 后台重启；CLI 软链不变，无登录项。已装 `--version` 0.1.1，可执行哈希与 receipt 一致。install.sh 在已安装时拒绝覆盖，所以按其步骤手工替换。
- 推送 2371333..779f30b（17 个本组件提交，无本机路径）；触发 GitHub「Core tests」CI，779f30b 已 success；无部署触发。GitHub Release v0.1.1 为 Latest，含 ZIP/DMG/SHA256SUMS，下载 ZIP 哈希与 release/latest.json 一致。gh 的 --target 须传完整 SHA，短 SHA 报 422。
- app_sop check-only：ship 全部 ok（build-receipt/install/release），test ok；accept 8/9 passed，homepage_desktop 在系统负载均值 300–900 时两次“无界面浏览器超时”。
- 未做：官网部署。build-site.py 拒绝在 release 与 perf 版本不一致时生成（“measure this release first”），需先对已装 0.1.1 空闲低负载实测 → 更新 README 数字块 → `bash scripts/deploy-site.sh`（同时上线已重录视频与 0.1.1 下载）。当前官网仍指向 0.1.0 下载（v0.1.0 资产仍在，链接有效）。

## 2026-09-28 13:5x 复查

- 系统负载均值 702/489/292（10 核），HID 空闲 3 s；占用靠前的是 diskimagesiod、Microsoft Word、Shadowrocket、iOS 模拟器运行时进程，均与本产品无关。
- perf（0.1.1 重测）与 homepage_desktop（builtin 无界面浏览器超时）仍卡在同一环境条件，未重试、未改验收方式；官网部署依赖 perf 重测。条件满足后依次：`app_sop.py run --app litegauge --stage perf --now` → `app_sop.py accept --app litegauge --check homepage_desktop --json` → `bash scripts/deploy-site.sh`。

## 2026-09-29 0.1.1 性能重测与官网上线

- 01:56 空闲门满足（HID 空闲 ≥600 s，负载 ~4）。首次 `app_sop run --stage perf` 失败：sop.measure 为 launch:false 但缺 `running`，batch_measure 拿不到 PID；补 `running: /Applications/LiteGauge.app/Contents/MacOS/LiteGauge` 后成功，app_sop 自动提交并推送 6312872（仅 perf/lightweight.json，无 CI 触发）。
- 结果（已装公证 0.1.1，已连续运行约 13 小时的常驻实例）：空闲 CPU 0.98%（目标 0.3%，用户已接受超标），footprint 23.0 MiB = 24.1 MB（0.1.0 刚启动 45 s 时 14.0 MiB；差异来自长时间运行，未查是否增长型问题）。安装包 ZIP 1.64 MB、安装后 1.85 MB；首个 CPU 读数 5 次中位 1238 ms（--benchmark 测试实例）。data/data_en 改为如实描述“常驻约 13 小时、非刚启动”。
- README 数字块由 perf_block.py 重新生成；`bash scripts/deploy-site.sh` 两次（第二次为改正说明），verify-site 逐文件、ZIP/DMG 哈希与视频 206 通过；线上 demo.mp4 与本地重录版一致。
- 相邻：内存随运行时间从 14 → 23 MiB，可在空闲时对新启动实例做 1 小时/12 小时两点对照，确认是否持续增长。apps.tianli.cyou 产品卡由门户组件消费本仓库 perf，门户部署不在本组件范围。
