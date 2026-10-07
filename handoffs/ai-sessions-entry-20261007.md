# 接续任务 D：LiteGauge 的会话快捷入口

**功能交付完成，整体视觉待收尾（2026-10-07）：轻仪 0.5.3 (15) 已公证装机；Cadence 1.3.0 (24) 已交付。缓存、路由和离屏目标页功能证据继续有效。用户实际截图揭示白色详情块与原生半透明操作菜单拼接，整体视觉验收未通过；后续只按 `handoffs/ai-sessions-visual-polish-20261007.md` 改造统一浮层。此前 48 项自检和局部 SummaryView 图片未覆盖完整弹出层，不再据此称整体 UI 完成。**

`cd /Users/tianli/Apps/litegauge`，新开 Codex，读本文件后执行。任务独立于协调聊天的三个 worker；当前没有人实现本项。

## 用户要什么

顺手看到 AI 主会话数量和状态，点击进入 Cadence 看各条任务。完整PRD：`/Users/tianli/Apps/cadence/docs/ai-sessions-prd.md`。

## 范围与依赖

保留固定56pt菜单栏指示器。原任务曾仅在详情面板加一行“AI会话”；用户视觉纠正后，改为完整弹出层统一材质、背景、字体和间距，资源、会话、操作在同一面板。具体新规格见视觉收尾交接，以下旧实施与测试记录只代表此前功能证据。用户点击进入Cadence实际会话页；不可用时明确说明，不假称已打开目标页。

只读 Cadence 提供的白名单派生会话缓存，具体文件/结构和任务 B核定。LiteGauge 不跑Python/ps/SSH、不解析原对话、不联网、不新建后台进程。缺缓存/过期显示未知，不能显示0。文案数字读同一缓存，不硬编码样本数4。

可先按PRD用隔离缓存完成读数/过期纯逻辑和离屏UI，实际缓存及跳转联调等B就绪。只修改新SessionSummary相关文件、原详情面板/CLI的对应小块和必要编译清单/测试；先查现有claims，产品CLI若仍由其他会话接入则拆开精确文件边界。不要改共享生命周期原版、内存回收策略/开关或其他产品。

## 验收与回执

- 无缓存、坏缓存、真实TTL、主/子计数、未知状态有隔离测试。
- 不扩大菜单栏宽度，不引入shell/network刷新，不输出任务私密正文。
- 用户点击路径和离屏真实详情面板验证；原资源读数/回收行为保留。
- 按本项目构建/装机约定交付，从已装CLI/实例核版本。先协调同产品已有构建，不并发抢装机。
- 完成后写回本文件：缓存契约、文件/版本、测试/真实UI、装机与待联调项。未联调跳转/真实缓存时不能宣称完整完成。

## 2026-10-07 接续实施 D（进行中）

- 本轮固定交付：Foundation-only 摘要读取/TTL/未知语义、真实详情面板一行、同源 `sessions status/open`、构建与离屏验证后装机；不扩展性能/官网/公开发版欠项。
- 已查 claims，无其他 LiteGauge 构建/CLI owner；保留现有工作树差异与内存策略。会话 `01a1150a-815b-7603-ac25-2953aeb7b7f9` 已声明本轮精确路径与装机目标。
- 消费 B 当前白名单缓存：`~/Library/Application Support/AutomationMonitor/sessions-summary.json`，`schema=1`，`ok/observed_at/expires_at/summary`；最大读取 64 KiB，完整摘要检查主会话状态和等于主数；部分覆盖保留已核数量，未知总数为 null。沿原 2 秒面板刷新，只在面板打开时读，不建新采集器或后台进程。
- Cadence 跳转已按 B 的实际源码契约适配：`cadence://sessions`，`CFBundleURLTypes` 中 `CFBundleURLName=Cadence AI Sessions`、`CFBundleURLSchemes=[cadence]`，bundle ID 为 `cyou.tianli.automation-workbench`。`Sources/main.swift` 的 `application(_:open:)` 调 `showSessions()`，B 已加路由自检。已装包缺少该声明时明确报“尚未提供入口”，不会打开总览冒充会话页。
- 文字在 `SessionSummaryWords` 共用；`~/Library/Application Support/LiteGauge/session-summary-words.json` 可覆盖说明/状态模板，坏数据整体回落。数量仅来自同一摘要。
- 轻仪侧已完成，最后待联调：B 新版 Cadence 的安装包声明/真实目标页。当前 /Applications/Cadence.app 仍为 1.2.1，无 URL scheme；轻仪 `sessions open --dry-run --json` 正确报 routeMissing。不能据此宣称跨产品跳转已完成。

## 2026-10-07 14:40 · D 已公证装机，保留 B 联调缺口

- 文件：新增 `Sources/SessionSummary.swift`、`Sources/SessionSummaryUI.swift`、`Tests/SessionSummaryTests.swift` 与 `Resources/session-summary-words.json`；只动 App/CLI/main 对应接入块、两份编译清单与捕获脚本的面板比例、版本/登记/双语说明。菜单栏仍 56 pt，详情面板高 344 pt。版本 0.5.3 (15)。
- `bash build.sh --test-only` / package 构建核心测试 **265 项通过**；最终二进制 `--ui-self-test build/session-delivery/ui-final` **48 项通过**，含主/子计数、可访问按钮、真实按钮 action、不可用说明、导航声明夹具、深浅渲染、原读数/回收/策略开关回归。图片已逐张看过，新增浅色面板背景，避免透明 PNG 难读。
- 原包、设置和开关：`bash scripts/install.sh --restart` 已从 0.5.2 (14) 升级到 `/Applications/LiteGauge.app`，后台实例 pid 1023。旧包在 `~/.Trash/litegauge-0.5.2-20261007-143819/LiteGauge.app`。装前装后 policy/history、141 个支持文件、偏好域哈希全部相同；已装原 `status --json` 仍成功，常驻实例未见网络套接字。
- 已装可执行 SHA256 **48fc88abd145a3188b8d938c5ca7d32b67fa792be314de31e23304b2edd68678**，与本轮构建一致；任务输入哈希未变。签名 Developer ID Application / B9LJH93LA4，App 公证 Accepted `d46744bd-04dc-49ea-8b62-57333fc1e0f9`，DMG 公证 Accepted `f9d8bded-1bec-466e-aee6-5350204baaa5`；已装签名与票据验证通过。后台 `scripts/package-release.sh` 退出 0，ZIP/DMG 在 `build/release/`，ZIP SHA256 `908768ed933254a09161c6934a7bffd823c4bcdc1404d19d4af2d6eecf0a29fc`。没有发布 GitHub Release、推送或部署官网。
- 真实缓存曾回读 `state=partial`，已核主会话 7、子 agent 4，与 producer 的 observed_at 完全一致；来源未齐总数为 null、退出 1。稍后同一缓存过期，已装命令回读 `state=stale`，主/子/各状态计数均 null，符合真实 TTL。未替 B 采集、续期或改写缓存。
- 实际离屏截图 `docs/media/panel.png` 由已装 `--snapshot` 生成（14:38:57），当前缓存过期所以显示未知，元信息写 `docs/media/manifest.json.panel`；原 0.4.2 视频只代表资源读数，没重录，不代表本轮入口或真实点击。
- 证据在 `build/session-delivery/`：`ui-final.json`、`ui-final/*.png`、`installed-readback.json`、`installed-regression.json`、`sessions-source-readback.json`、`sessions-installed.json`、`navigation-installed.json`、`package.log` 与 `package-result.json`。`sop-check.json` 是交付前只读检查文本：原 SOP 缓存仍有旧测试绑定/receipt/性能/媒体/公开发行欠项，本轮有效的 265/48 项与真实装机回执不因此作废；未扩展为全产品补课。
- 未覆盖：物理菜单点击、LaunchServices 实际打开已装 Cadence 会话页；当前 B 安装包还没更新。B 新包提供既定 URL 声明后，轻仪不需重装即可识别，下一步先 `litegauge sessions open --dry-run --json` 核成功，再沿无干扰窗口做双方目标页联调。
- 14:44 后定位到等待原因：原生 `thread/read` 对 B (`01a11507-e027-7553-b642-cde37565b396`) 的最新 turn 回读为 `interrupted`；最后进度为“页面、双机采样和同源命令已实现……准备统一构建和装机”。不能将其空闲摘要当成已经完成。B 的 claims 仍在、当前 D 不允许改其他产品，已向用户询问由原 B 会话继续还是 D 接管构建装机；未擅自恢复模型、接管声明、运行 Cadence 构建或替它装机。

## 2026-10-07 15:19 · 已装 Cadence 最终只读联调

- 原负责会话已完成安装：`/Applications/Cadence.app` **1.3.0 (24)**，native SHA256 **fd796b8730bb14cbeac4de58c61a4155c8e0a8e9069165166ae01d933b888405**，与 B/Bark 两份回执一致。本轮不重建/重装轻仪，不接管或安装 Cadence，不修改其源码。
- **dry-run**：已装 `litegauge sessions open --dry-run --json` 退出 0、`ok=true/state=preview/url=cadence://sessions`。这只证明消费者识别安装包的跳转声明，没有发送打开请求。
- **实际系统注册**：只读原生 `NSWorkspace.shared.urlForApplication(toOpen: URL(string: "cadence://sessions")!)` 返回 **`/Applications/Cadence.app`**；实际 LaunchServices 映射已核，区别于仅看 Info.plist。
- **真实摘要**：15:19:27 回读的新鲜缓存 `state=partial`，已核主会话 7、子 agent 0，工作 5 / 等待 0 / 空闲 2 / 未知 6；双机总数为 null。`observedAt` 与 producer 完全一致、八项数量字段逐项比对一致。Mini 来源未知导致总数未知，属于真实来源覆盖状态；不是入口故障，不当成 0。
- **实际目标页/现有离屏证据**：复用并目视 B 的 `perf/raw/local-ai-sessions.png`，生产会话视图确有 AI 会话标题、已选侧栏、主/子/未知和双机信息；该图是已装程序在隔离演示任务外壳中加载真实会话摘要的离屏图，不能称用户当前窗口或实际 URL 点击。原 B 的 `sessions_deep_link_routes_only_own_page` 自检覆盖 URL 解析，尚未单独断言 `application(_:open:)` 执行后 `model.section == .sessions`。协调会话已把这一个缺口交原 B 补最小离屏验证，不重复派活。
- **物理点击/真实前台打开**：没有执行。只读 CUA 当前窗口能见 AI 会话入口，但尚在总览；HID 空闲仅约 0.08 秒，用户正在使用桌面。生产 URL 回调会 `makeKeyAndOrderFront`/`NSApp.activate`，所以未发起可干扰前台的 CLI open、CUA 点击或模拟输入；也不申请打破永久输入/焦点约束的例外。
- 结构化回执：`build/session-delivery/integration-readback.json`。轻仪已装 SHA 保持 **48fc88…68678**；本轮只读验证与本文件更新，随后释放工作槽。上一节“Cadence 还未装机”和接管选择已被本节事实取代。

## 2026-10-07 · 最终收口：生产路由离屏验证已补齐

- B 的 `perf/ai-sessions/route-callback.json`/`route-callback.png` 已产生，原验证退出 0（约 6.4 秒）。测试从 `overview` 开始，向已装生产 `AppDelegate.application(_:open:)` 传入 `cadence://sessions`；原 URL parser、callback、`showSessions` 和 section 选择逻辑保持，单独在测试进程拦截 AppKit 展示/激活请求，不改已装二进制。
- JSON 回执记录 `callback_available=true`、展示和激活请求各 1 次、`visible_windows=0`。已逐图看过对应截图：侧栏 AI 会话被选中，页头为 AI 会话，显示生产页面的虚构样本摘要。截图 SHA256 **5f3ab4151c57be6ee38a8ef4a350a9f3606388894887f7f2fee3b70b04665038** 与回执一致；已装 Cadence native SHA **fd796b…88405** 与回执一致。此前唯一离屏覆盖缺口已关闭。
- `build/session-delivery/integration-readback.json.production_route_offscreen` 已补原件位置、两项哈希比对与范围；不复制第二份业务实现或重复测试/构建。物理用户点击、真实可见的 OS URL 打开仍未执行，不能将这份测试称为桌面实机点击录制。
- 最终状态：D 产品实现、265 项核心/48 项轻仪离屏自检、签名公证/装机与设置保留、真实白名单缓存消费、系统注册映射、生产路由到目标页的离屏证明均已交付。无待本人审批或跨产品接管；源码保留本轮及既有未提交差异，没有公开推送/发布/官网部署。
