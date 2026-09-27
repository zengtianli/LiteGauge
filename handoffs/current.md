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
