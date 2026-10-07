# LiteGauge 视觉收尾：统一整个弹出层

状态：已完成并实装 **LiteGauge 0.5.4 (16)**。完整生产浮层正常/部分来源/过期/缺失的浅深色 8 图已目视；265 项核心、70 项 UI 检查通过。原独立 D 会话完成改造与公证装机后，用户要求关闭它、由本会话接管收尾；原 turn 已 interrupted，最后已装回读、设置保留与交接由本会话完成。范围与实际未覆盖项见末尾。

进入目录：`cd /Users/tianli/Apps/litegauge`。阅读本文件、原项目指导、`handoffs/ai-sessions-entry-20261007.md` 的既有功能回执及 `/Users/tianli/Apps/cadence/docs/ai-sessions-prd.md`。

## 用户明确的最终效果

整块弹出层统一、清楚、好看。上面资源读数和下面操作区不能使用两种割裂的背景；不是只改 AI 会话那几行。LiteGauge 作为快捷摘要入口，完整会话、任务、目录与来源详情继续由已有 Cadence 展示，Chapter 继续负责派活边界。

设计小样：`docs/design/ai-sessions-panel-20261007.svg` 与同目录说明，数字仅为设计示例。原菜单栏 56 pt 保持，弹出层建议约 360 pt；56 pt 不限制弹出层宽度。

## 必须整体改对

1. 点击菜单栏后显示一个原生 AppKit 浮层，建议 `NSPopover` 与 `NSVisualEffectView` 的 popover 材质。整个浮层一套连续背景，跟随系统浅深色；资源、会话、操作用留白和细分隔线分组。不得保留“白色 SummaryView + 透明 NSMenu”拼接。
2. 紧凑保留 CPU、内存、启动磁盘读数及压力/交换/剩余等有效信息，单位和对齐一致。沿原采样和刷新，不改自动回收策略。
3. 独立 AI 会话节，突出已核主会话数和有意义的工作状态；部分来源待核时保留已知信息，过期或缺失则明确显示待更新/不可确认。零项减少重复展示，子 agent 保持独立口径。
4. 明确“查看全部会话”操作，沿已验收的 `cadence://sessions` 路由。LiteGauge 不承接完整任务、目录列表或另造调度业务。
5. 底部操作使用同一浮层背景和统一字号。保留立即刷新、资源建议、内存自动处理及其真实状态、活动监视器、设置、检查更新和退出等原动作；次级操作可归入“更多”，不能在设计中消失、改动作或丢失原快捷键。
6. 保留点击外部/Esc 关闭、键盘导航、VoiceOver、错误说明及系统浅深色行为。采集缓存仅在浮层打开时读取；LiteGauge 仍无 shell/Python/SSH/联网采集。

## 摘要文案边界

数据沿 `~/Library/Application Support/AutomationMonitor/sessions-summary.json` 原白名单、TTL 和 null/partial 语义。当前没有主机级摘要，不得凭 aggregate unknown 显示“只有 Mini 未知”或“Mini 离线”。

只读核验发现，全域待核候选可能同时包括本机陈旧 Claude 登记与 Mini 候选；已核与待核采用不同口径，不能相加冒充准确总数。界面可显示“已核 N 个主会话”与“部分来源待核”，完整原因交 Cadence。演示用的 6、工作/空闲数字不能写入运行时常量。

若实现者认为必须增加主机级摘要，应先将精确数据依赖回传调度并划清 B/D 文件边界；本视觉任务不擅自改 Cadence、共享 core 或 mini 采集。

## 文件责任

- `Sources/App.swift` 的菜单/浮层容器、详情生产视图与原动作接线；原采样、状态指示器和策略逻辑保留。
- `Sources/SessionSummaryUI.swift` 与 `Resources/session-summary-words.json` 的摘要排版/文案；数据读取层保持真实口径。
- 可新增本仓独立 `Sources/PanelUI.swift`；仅在相关 AppKit 编译清单中接入。
- `main.swift`、`scripts/capture/main.swift` 与截图入口的必要改动，确保输出完整生产浮层内容。
- 新视觉/可访问性验证、媒体与本交接；版本、构建和安装按项目原流程处理。

你不是独自在仓库。开工先查原 claims 并原子声明精确范围，保留他人未提交修改。没有其他产品源码、共享规则、Chapter、Cadence 构建或系统权限的写入责任。

## 为什么此前基本检查漏掉

- `Sources/App.swift` 的离屏 `png` 函数只画传入的 NSView，旧自检浅深色均传 SummaryView；`--snapshot` 和旧 `scripts/capture/main.swift` 同样单独创建 SummaryView。
- NSMenu 结构检查只核项目/退出/快捷键/动作；原生下半操作菜单未进入图片。
- 像素数量检查只证明有内容，不能证明美观、对比度或排版。

因此，旧 265 项核心、48 项离屏检查、签名公证与装机回执仍是功能证据，不能称为整个用户弹出层视觉验收。

## 完成条件

- 先核生产完整浮层的小样与规格一致，再沿原离屏机制捕获完整内容：资源 + 会话 + 全部底部操作 + 整体容器；禁止只输出顶部 SummaryView。
- 目视同一背景和材质，检查字体/对齐/分隔/留白、按钮层级、浅深色和有效对比度。覆盖正常、部分来源、过期/缺失状态，数字来自夹具或真实缓存且标清来源。
- 原资源读数、回收开关/行为、快捷键、设置、更新与退出沿生产动作做必要回归；CLI 与新面板读数同源，缓存不擅自续期。
- 所有自动 UI 验证离屏，不上屏、不抢焦点、不合成输入；真实前台点击未做则如实写明，不能以测试数目替代目视。
- 按项目原构建、公证、安装流程，仅装 LiteGauge；保留偏好和设置，从已装版本捕获完整视图并回读。
- 回执写本文件：精确文件/提交、已装版本、完整生产图位置、人工目视结论、功能回归、设置保留、覆盖与未覆盖。功能通过但整体视觉未通过时任务保持未完成。

## 其他原任务复核

A 核心/SOP、B Cadence 功能和链接回调、C Chapter 边界、E 工具授权回执已复核；本次视觉纠正只重新打开 D 的整个浮层视觉交付。额度监控仍沿既有入口，多个独立 Claude/Codex 主会话与两机协作的原架构不变。

## 执行回执 · 2026-10-07

- 改造完整 `GaugePanelView`，实际 `NSPopover`、`--snapshot`、UI 自检和媒体入口均用这一生产视图；资源、AI 会话及全部底部操作共用 popover 材质。菜单栏仍 56 pt，浮层 360 × 650 pt。系统强调色主按钮有真实可用/不可用差别，普通操作为清楚的 labelColor，页脚弱一级。
- 新增 `Sources/PanelUI.swift`；适配 `App.swift`、`SessionSummaryUI.swift`、原入口与必要编译/媒体清单，更新词表、Info 版本。采集、缓存读取语义、内存策略和其他 App 源码未因视觉改造而重写。
- **265 项核心、70 项 UI 检查通过**。完整正常/partial/stale/missing × 浅深色 8 图已由原负责人逐图目视，并由当前会话及只读核验分组目视；原背景断层、灰色主入口和二级操作像禁用的问题均已修正。7 个原动作截图前后 enabled=true、target=AppDelegate、selector 可响应，隔离 probe 派发通过；未执行真实退出或打开其他 App。
- 证据 `build/full-panel-final/result.json`、`receipt.json` 与 `native-ui-full-*.png`；binary、8 项源码、8 图 SHA 已独立重算匹配。公证流程正常重签/重构建后产生最终安装包，当前源码 8 项 hash 仍与该 UI 验收绑定，原图未冒充最终已装二进制。
- App 与 DMG 公证 Accepted：`238713e2-cd3b-436e-a0be-61a16e310205`、`950c9133-655b-46b8-a71b-9ab6498bd651`。`package-result.json` exit 0；本地 ZIP/DMG 在 `build/release/`，未发布 GitHub Release 或部署官网。
- `/Applications/LiteGauge.app` 已为 **0.5.4 (16)**，后台实例 pid 95323；安装脚本通过原 CLI 正常结束旧 0.5.3 并 `open -g -j` 后台重启。旧包在 `~/.Trash/litegauge-0.5.3-20261007-155033/LiteGauge.app`。已装与最终候选 executable SHA 同为 **5a2dbc193ef25f2d445f2a304762fa8826a2ffb1fc869724a94478ed3896a7a5**。
- 当前会话实际执行并通过 codesign 严格核验、stapler validate、spctl assess，输出 Notarized Developer ID。比对装前记录：**141 个原支持文件无缺失、无内容变化，原 defaults 哈希相同**。
- 已装 `--snapshot` exit 0，完整生产图 `build/full-panel-final/installed-panel.png` 已目视，统一背景、正常可读动作及真实白名单缓存读数均在同一图。该图 SHA **336392bc8d52012e75d565e779db0a00de1731a6ef3555563d4d4d9dd84d2185**；结构化最终回读为 `installed-readback.json`。图上动态数量仅代表采样时刻，不作固定配置。
- 未覆盖：真实物理点击、系统 popover 箭头/外阴影及实际桌面背后材质；自动步骤保持离屏，未抢焦点或合成输入。完整生产内容与实际 view 接线已覆盖，此限制不得写成真实前台点击通过。
- 原离线全局 SOP 查询被范围外 `Apps/lumen` 缺 project.yaml 阻断；没有更改该项目，也没有用此替代本任务的实际构建/核心/UI/公证/已装证据。
- 版本保存边界：全新 `Sources/PanelUI.swift` 与独立交接可限定提交；`App.swift/main.swift` 等已有工作树差异包含此前其他 owner 的改动，未整文件夹带提交或撤销。8 项实际验收输入另存 `build/full-panel-final/source-snapshot.zip`，逐项校验与 receipt hash 一致；该归档是当前构建输入快照（包含既有工作树状态），不是 UI-only patch，不应直接覆盖他人源码。原闭合 D 会话的归档仍保留完整操作证据。已装产品和完整视觉核验均有效，不冒称整个源仓工作树已干净。
