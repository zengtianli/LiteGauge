# 轻仪 LiteGauge · 当前交付

## 2026-10-07 18:40 · Agent 命令入口第二轮：「升级到新版」与同步状态那句有命令，0.5.5 (18) 公证装机

来源：全产品「每项功能都能不点界面完成」第二轮。共用层定稿后「升级到新版」和「配置同步状态那句话」都有命令，轻仪的帮助、测试、自检、登记跟上并装机。声明会话 `agentcli2-litegauge`。这个单元由两个执行者接力：前一个 17:46 开工，18:05 随主会话重启被结束，没有留下回报；本节由接续者写，前任留下的每处改动都读过、测试都重跑过才沿用。

结果：

- 装上了。0.5.5 (17) → 0.5.5 (18)，装前装后 `spctl -a -vv` 都是 accepted / Notarized Developer ID，`stapler validate` 通过。可执行 SHA256 `f9e5752f72363008…` → `c9c64e456d5d79e7…`。菜单栏实例后台重启，pid 87514 → 55540，装机前后最前面的应用都是 Ghostty。
- 换下的 0.5.5 (17) 在 `~/.Trash/litegauge-0.5.5-20261007-183441/LiteGauge.app`（安装脚本自己放的）。
- `chapter agent-cli`：上次验收（12:03）未通过，35 项 = 命令 30、仅在窗口 3、暂缺 2；现在 `passed`，37 项 = 命令 34、仅在窗口 3、暂缺 0（多出的 2 项是下午 D 布局那轮加的 AI 会话摘要与跳转，不是本轮加的）。

新命令（都来自共用层，轻仪只接线）：

- `litegauge update install --yes [--dry-run] [--json]`：设置窗口「升级到新版…」那条路。没有新版退出 0、`installed:false`；`--dry-run` 报 `would_install{from,to}`；有新版缺 `--yes` 退出 2（`confirmation_required`）；窗口里是「下载新版…」的情形退出 1（`manual_install`，带安装包地址）；成功时旧 App 移到废纸篓（`old_app_cleanup:"trashed"`、`backup` 为 null）。
- `litegauge config status` 多了 `sync_status{text, at, from, live}`：开关下面那句同步状态。原有字段没变。
- `update check` 的 `upgrade` 多了 `command`。

改了什么：

- `Sources/CLI.swift`：顶层帮助删掉「暂无命令」两行，加 `update install` 的用法、`--json` 形状、error.code（`manual_install`、`needs_product_installer`、`upgrade_failed`、`app_busy`、`replace_failed`、`cleanup_failed`）和退出码说明；`update install --yes` 列进「有真实后果的写命令」。
- `Sources/ProductLifecycle.swift`：帮助直接拼共用层的 `helpRead` / `helpWrite`；`runningApp` 交给共用层（升级前退出的就是它）；隔离运行（设了 `APP_LIFECYCLE_SUPPORT_DIR`）且 `LITEGAUGE_UPDATE_CHANNEL` 以 `test.` 开头时才换成一次性的本地渠道，其余情况一律是 GitHub 正式发行；隔离运行只认 `LITEGAUGE_LIFECYCLE_APP_PID` 指的那个进程，不看也不退出本人正在运行的实例。
- 生命周期自检 `--lifecycle-self-test` 从 43 项加到 56 项：同步状态那句（初值、运行中的 App 此刻那句与窗口逐字相同、App 没在运行时取记录、关闭后回到「已关闭」）；`update install` 没有发行记录、没有新版、`--dry-run`、缺 `--yes`、多余参数；`update check` 的 `upgrade.command` 与窗口入口名；全程不带 `--yes`，核对被测 App 没被替换、没有下载任何东西。
- `Tests/main.swift`：核心测试 276 → 278 项（帮助不再有「暂无命令」、登记里没有 missing、新形状与 error.code）。
- `project.yaml` `sop.agent_cli`：「升级到新版… / 下载新版…」改 `command: litegauge update install`，「同步状态那句话」改 `command: litegauge config status`，「设置…」的说明去掉「暂缺的两项另列」。
- `Info.plist` 构建号 17 → 18（版本号 0.5.5 没动；没有跑发版脚本）。
- README 中英文、CHANGELOG、`scripts/accept/lifecycle.sh` 的说明同步。
- 四份共用副本（AppLifecycle / AppConfiguration / AppLifecycleUI / AppLifecycleCLI）与总部现版逐字节相同（`3033bc6f… / ba4d6aa1… / fb946d73… / f33393d9…`，开工时、构建后各核一次），没有产品自己的本地改动。

怎么验的：

- `CODE_SIGN_IDENTITY=Developer ID Application… bash build.sh`：核心测试 278 项通过。
- 对构建产物：`bash scripts/accept/lifecycle.sh` 56 项通过，背靠背回退 0 次，共跑命令 417 条；`--ui-self-test` 108 项通过。两个都是离屏，没有窗口上屏、没有状态栏图标。
- 另在隔离环境里手工跑了一遍公证过的那份（临时策略目录、测试偏好域、临时「云」目录里的一次性渠道，没有联网）：`config status --json` 带 `sync_status`、退出 0；没有发行记录退出 1（`check_incomplete`）；同版本退出 0、`installed:false`；更高版本 `--dry-run` 退出 0 并给出 `would_install`，缺 `--yes` 退出 2（`confirmation_required`），`--no-such` 与多余参数退出 2（`usage`）；被测 App 的可执行前后哈希相同。
- 公证：另存一份提交，提交号 `3e24145b-0fc8-495c-975e-e748738ec416`，Accepted，装订后 `spctl` 与 `stapler validate` 通过，可执行与跑过自检的构建逐字节相同。只做了提交与装订，没有跑 `scripts/package-release.sh`；`build/release/`、`release/latest.json`、GitHub、官网都没动。
- 装机：`bash scripts/install.sh --restart <公证过的副本>`，18:34。装前（18:34:39）装后比对：`defaults export cyou.tianli.litegauge` 相同（空域）；`~/Library/Application Support/LiteGauge/` 141 个文件内容、修改时间、大小全部相同；`care status` 的策略与历史、`care budget status` 的设置、`care protect list` 的 20 条规则全部相同；`~/.local/bin/litegauge` 与 keys.d 软链未变；`TianliApps/Configuration` 下仍没有轻仪的目录。系统后台项列表（`sfltool dumpbtm`）与 LaunchAgents 里装前装后都没有轻仪：产品不自动加登录项。
- 装机版只读验证：`--help` 有 `update install` 各行、没有「暂无命令」；`config status --json` 有 `sync_status`（同步关着：`text` 为「iCloud 配置同步已关闭」）；`update install --no-such --json` 退出 2、`error.code` 为 `usage`。17 条只读或错误参数调用的退出码 18 与 17 逐条相同，其中 15 条 JSON 输出的键也逐条相同（另两条是帮助与不带参数的用法）。
- `chapter sop accept --app litegauge --check agent_cli`：passed。

冲突副本：共 18 个，全部是 10-05 的旧版，当前文件都比它们新，没有「新内容只在冲突副本里」的。落在编译或打包路径里的 13 个由前任移到 `handoffs/sync-conflicts-20261007/`（保留相对路径，不提交）；其余 5 个（CHANGELOG、两份 README、CLAUDE、本文件的冲突副本）没动。

没做或没验证：

- 没有对装机版跑过 `update install --yes`，也没有跑联网的 `update check`。真实替换一次 App 只有共用层自己在夹具 App 上的测试；轻仪这边验的是到替换之前的每一步。GitHub 上的正式发行还是 0.4.1，现在跑 `update install` 只会回「不需要升级」。
- 同步开着时装机版的 `sync_status`（`from: app` 那句）只在离屏自检里验过，没有对本人真实的 iCloud Drive 拨过开关。
- 没跑性能测量，`perf/lightweight.json`、构建与装机回执都没动；`scripts/accept/*` 里会重新构建的四个（functionality、recovery、privacy、native_ui）没跑。
- `scripts/accept/lifecycle.sh` 仍没有登记进 `sop.accept`。

留在磁盘上的：留底与日志在 `build/agentcli2-20261007/`（`before-2/`、`before-3/`、`after/`、`isolated-manual/`、构建与公证记录）；`build/LiteGauge.app` 是签过名、未装订的 18（可执行与装机版相同）；公证过的那份装完后移到了 `~/.Trash/litegauge-agentcli2-notarized-copy-0.5.5-18-20261007-183623/`；前任开工时把上一轮留在 build 里的 0.5.5 (17) 移到了 `~/.Trash/litegauge-build-0.5.5-17-20261007-175920/`。

提交（本机，未推送）：一次提交，信息以 `Agent CLI round 2:` 开头。提交里有登记的两项改动与「设置…」那行、`Sources/ProductLifecycle.swift`、三份有变化的共用副本、`scripts/accept/lifecycle.sh`、agent_cli 验收记录和本节。`Sources/CLI.swift`、`Tests/main.swift`、`Info.plist`、两份 README、`CHANGELOG.md` 带着 0.4.4 到 0.5.5 别的轮次的未提交改动，本轮的修改叠在上面，仍未提交，留给发版流程；`project.yaml` 里 D 布局那轮加的两行 AI 会话登记和本文件里它的 16:42 一节同样没有带进这次提交。

## 2026-10-05 · 0.4.3 关闭浏览器已装机；实际内存目标仍未达到

- 用户明确纠正：Dia 等浏览器直接关闭即可，不要恢复重启；最终标准是实际释放内存，并由 LiteGauge 一次处理，无需逐个点击。该约束覆盖 GUI、CLI、规划、动作、策略、结果、测试和当前说明；aTrust 保留。旧重启模式停止使用。
- 已用已安装 CLI 实际正常关闭 Dia，未再打开；Chrome 已不运行。复查证明浏览器进程退出、系统已用内存实际下降。个人机器原始证据仅存忽略的 build/browser-close-*.json；不能把暂时下降当作持续降低到一半。
- 主动浏览器关闭不受旧高占用阈值、重启冷却、前台/CPU 条件限制；核权限、内存读数和真实身份，保存提示仍由应用处理。后台关闭保留高压力、持续高占用、空闲与低负载保护。旧重启许可不能自动授权保持关闭，本次用户已明确授权，装机后沿实际 CLI 开启关闭策略。
- 0.4.3 (10) 已签名、公证、安装并后台运行。最终源码 72f08ddb0d2c77538989731335e6099858f77eaf，核心 124 项通过；已安装可执行 SHA256 b9228b98f19d51160a030065d45f32efec68f1551d0c907033c9146add2eaacf 与构建回执一致。真实已安装 CLI 零项路径返回 no_action / ok=false / 退出码 1，没有假报成功；关闭许可、后台开关保留。
- 实际正常关闭 Dia、Sift、未播放的 Music；停止确认无连接且已结束用途的旧 WrongBook fixture 和邮件 mock 服务，保留工作应用与后台业务。用户进一步授权停用京东羊毛；青龙 48 个京东及 1 个顺丰积分任务、本机订阅与探活已暂停，容器和 OrbStack 服务、App 已正常停止，开机启动关闭；配置与数据保留，VPS 未动。现行暂停和回退入口在 Qinglong 原仓 handoffs/resource-pause-20261005.md。
- 用户最终标准明确为 16 GiB 机器实际已用内存低于 8 GiB。停用青龙/OrbStack 后约 11.2 GiB / 70%；随后用户明确允许关闭微信，已用装机 CLI 正常退出并保持关闭，微信进程组计账 1.0 GiB → 0，整机即时 11.32 → 11.01 GiB、后续约 10.9 GiB / 68%。仍未达到，不能称高内存已解决。当前 Codex/终端工作和 aTrust 保留；是否允许处理完后关闭当前 Codex 客户端正待答复。应用计账内存不能直接相加作为物理 RAM 收益。
- 仅更新此次受影响的资源诊断截图与中英文说明，沿用 CPU/内存/磁盘视频。公开下载和官网仍为 0.4.1，本轮没有发布/部署；不将推广流程作为本机内存处理的前置。已安装版离屏 UI 25 项曾通过；最后冷却修正不改变界面，不把离屏核验写作实际用户点击验收。
- 最终修正及交付证据已推送；GitHub Core tests 37269568389（8d7da8a）成功。其他后台 SOP 写入的 perf/acceptance 与 delivery-evidence 差异保留，不纳入本轮提交。
- 14:35 用户自行关闭 Codex 客户端后追问负载仍高。现场确认桌面主程序已退出，4 个终端 Codex（本任务及另 3 个工作区）和共享 app-server 仍在；其他工作有活跃声明。单次 CPU 6% 不能代表持续状态，后续连续采样出现 20–42% 波动；top 抓到同步、Spotlight 索引、媒体分析等间歇活动，随后单次 CPU 约 5%。整机内存仍约 10–11 GiB，压力正常，其中系统/驱动 wired 约 3 GiB、物理压缩约 1.7–1.8 GiB；LiteGauge 已排除约 4 GiB 文件缓存，不能再归因为纯缓存。回收了本会话不再使用的 CUA JS 运行环境；其他工作保留。中断其他开发任务以优先清理的选择正待用户答复，不能暗中关闭共享 daemon 或把单次低 CPU 写作负载已解决。独立 RPC 代理的 thread/list 返回 notLoaded，仅说明该代理未加载线程，不能用它判定现有 daemon 的工作已结束。

## 2026-10-05 · 0.4.2 本机按钮与 CLI 真实核验

- 用户反馈按钮仍无效果，已通过 CUA 读取实际已安装 0.4.1 窗口：自动处理暂停，当前零项，按钮禁用；顶部还展示已不在运行的浏览器历史失败。实际 CLI `care run --yes --json` 零动作却返回成功。修复手动权限与后台开关耦合、零项不能重新扫描、历史结果与当前状态混淆、零动作假成功四处问题。
- 0.4.2 (9) 已 Developer ID 签名、公证并安装到 /Applications；后台唯一菜单栏实例与 CLI 均为新版。已安装可执行 SHA256 f1d91c848e39e0b8d8e3b16d394da32bd3190595edd73eb938d9738287658757，与 perf/build-receipt.json 及全部 17 个源码输入一致；源码 56663b491bc687dac27a9268bcddbbcfa86731ca。
- 核心 118 项、已安装版离屏 UI 24 项通过，macos-14 CI 37267410496 成功。已安装 CLI 实际返回 no_action / ok=false / attemptedCount=0 / performedCount=0 / 退出码 1；预览独立标记 preview、退出码 0。单次手动点击即使后台暂停且当前零项，也能在已有允许范围内重新诊断；没有允许时仍不可执行。
- 本轮实际执行过一次 Dia 正常会话备份、正常退出与后台恢复，随后独立等待并复测，收益有限且使用后回升。原生实操使用的是升级前 0.4.1 适配器；0.4.2 安装后测试的是实际 CLI 零项路径，不能将其写成新版真实重启成功。没有核验恢复标签数，没有强杀浏览器或确认丢弃表单，aTrust 和工作应用保留。
- 新版浏览器退出等待 30 秒，并区分拒绝与未退出；恢复后等 30 秒再复测。身份读取失败不能直接当成进程已退出。保持成功冷却与低收益保护，明确手动重试可略过失败冷却，后台仍保留保护。
- 本机后台当前暂停，原有四项允许保留；未自动覆盖当前暂停状态。个人机器内存、进程和操作原始证据仅存忽略的 build/。总内存明显下降尚未达成，不能宣称已解决高占用或达到 50%；当前内存压力正常。公开证据见 perf/cli-care-verification.json。
- GitHub 下载与官网仍为 0.4.1；0.4.2 签名候选包位于 build/release/，本轮以修复与装机验证为主，未发布新版下载或部署官网。同源离屏素材已更新为 0.4.2；不能称为实际用户点击录像。正式性能仍为历史 0.1.2。交付前 SOP test-only 已调用，返回增量状态待检查，不代表全量验收通过；保留其他后台作业的证据原件。

## 2026-10-05 · 0.4.1 修复「按建议处理」无效果

- 实际原因：旧按钮在主动点击时仍要求系统高压力；正常压力下仅返回等待。主动操作现在略过压力、空闲与第二次读数条件，保持既有权限、完整读数、身份、前台、CPU 与冷却保护；后台自动规则不变。一次点击按初始可执行计划逐项处理，每项前复查条件。
- 按钮显示可处理项数，仅存在可执行项时启用；进度、完成项数、内存变化和失败/略过原因置于顶部。真实 AppKit 按钮直接激活的离屏回归覆盖成功、零项、多项与条件变化，实际窗口结果布局可见。
- 已实际走浏览器原生恢复路径：Dia 完成；Chrome 因未保存页面的 Leave site 提示未退出，保留页面，记录失败并按原规则暂停重试。没有强制结束、没有自动确认丢弃表单；不能声称两者均处理成功，也未核验恢复标签数。个人机器占用与进程证据只在忽略的 build/。
- 110 核心、22 离屏 UI、14 CLI 计数器、4 只读规划、4 动作身份检查通过；macos-14 CI 37258707299 成功。源码 dbd2d2e，0.4.1 (8) 签名/公证发行版已装机运行；可执行 acc4e3379ffc 与回执及全部 17 个源码输入一致。本机原有四项权限保留，aTrust 保留。
- GitHub Latest 和官网已发布 0.4.1；14 个公开文件、ZIP/DMG SHA256、视频 Range 206 验证通过；Chrome 当前 683 px 视口、诊断图加载及 24 秒视频实际完整播放通过，核验标签关闭，原用户 5 个标签保留。证据见 perf/manual-care-verification.json。
- 正式性能仍为 0.1.2 历史实测；不在本次按钮修复中扩展账号/冷启动任务。增量 SOP test-only 曾返回；最终 check-only 更新遇另一轮 SOP 锁，保留后台作业和原件，不能据此宣称全部 SOP 通过。

## 2026-10-05 · 0.4.0 浏览器恢复

- 用户再次反馈总内存仍高；基本后台照料覆盖不足。新增 Dia / Chrome 另行一次允许的恢复重启，不再把主要占用未处理泛称为无需重启。当前会话用户已明确允许空闲时自动恢复，本机策略已开启；不能绕过空闲条件立即重启。
- App 保留普通 SNSS 会话备份后正常退出，请求 `--restore-last-session`。不核验恢复标签数量，不保证无痕页面、未提交表单、下载或页面任务恢复。两份 owner-only 本地备份；6 小时观察，降幅不足 10% 时暂停 24 小时，允许单独撤销浏览器恢复。
- 107 项核心、17 项离屏 UI、14 项 CLI 读数、5 项隐私检查通过；两个本机浏览器正常会话及原生适配器预检通过。常驻实例已按新规则记录第一次高占用，仍等二次读数与用户空闲；本轮尚未证明实际浏览器降幅/标签完整恢复。
- 0.4.0 (7) 已签名、公证、装机（可执行 2fb39f3001de），GitHub Latest 与官网已同步。构建源码 14aad69；两次 macos-14 CI 均通过。详见 perf/browser-recovery-verification.json；个人机器原始调查、进程身份、标签记录只在忽略的 build/，不公开。
- 演示素材为同源 AppKit 离屏渲染；诊断截图挂载真实离屏窗口以正确布局，无前台窗口或输入。正式空闲性能仍受 in_use:false 限制，0.1.2 为历史实测；SOP 原账号形态和冷启动缺口未在本次内存功能中扩展处理。

## 2026-10-05 · 0.3.0 具体建议与自动处理

- 用户纠正逐个点击的处理流程。资源面板先给具体建议，主流程改为一次允许后的后台照料，aTrust 与工作应用保留。0.2.0 的逐项手动操作已被此流程替代。
- 自动处理仅支持 Shadowrocket / OrbStack；公开默认关闭。本机会沿当前会话授权直接开启，用户无需逐个选择。持续高压力、两次高占用、空闲/前台/CPU/覆盖与身份共同约束，成功/失败有冷却，本机保留最近 20 条结果。
- 已通过 91 项核心检查、17 项离屏界面检查、CLI 与隐私边界；0.3.0 (6) 已 Developer ID 签名、公证、装机与后台重启。本机自动处理已开启，常驻实例已自行写入后台检查结果。构建来源 bfc9edc，GitHub CI 成功。
- GitHub v0.3.0 已设为 Latest，官网已同步，14 个公开文件与 ZIP/DMG 哈希一致。Chrome 当前 683px 视口完整页面已审阅，演示视频实际播放至 24/24 秒；本轮没有重复 1440px / 390px 视口。验证范围见 perf/resource-care-verification.json 与 perf/promotion-verification.json。
- 正式空闲性能重测仍需等待符合项目 in_use:false 门；历史 v0.1.2 实测明确标注，不能代表 0.3.0。个人机器调查在忽略入库的 build/，不公开。

## 0.2.0 历史诊断版本

- 新增原生按需诊断、应用进程合并、内存/CPU 排行、正常退出和受控重启后复查；OrbStack 官方命令与 Shadowrocket 系统连接适配。保留 56 pt 菜单栏与原采样节奏。
- 核心检查 65 项、离屏界面检查 15 项、CLI 检查及隐私边界通过。公开截图使用固定示例值，真实动作与个人机器调查记录仅保存在本机 build/。
- 新版正式性能待空闲重测，保留 perf/lightweight.json 原版历史实测；当前发布与装机事实以 release/latest.json 和 perf/build-receipt.json 为准。
- 0.2.0 (5) 已 Developer ID 签名并完成 ZIP/DMG 公证、装机及后台重启；源码 5b8e39c，GitHub CI 通过，发行入口为 v0.2.0。本机 CLI 已核版本、诊断输出和唯一菜单栏实例。

2026-09-26。用户要求极简 CPU/内存/磁盘监控、紧凑菜单栏、改名且保留 Stats；随后授权 GitHub 与 product-homepage 推广。

## 当前入口

- 官网：<https://litegauge.tianli.cyou/>
- 源码：<https://github.com/zengtianli/LiteGauge>，MIT，中文 README / 对应英文 README。
- 公开正式版：<https://github.com/zengtianli/LiteGauge/releases/tag/v0.4.1>（Latest）；本机 0.4.3 尚未公开发版，旧版本资产仍在。
- 目录：<https://apps.tianli.cyou/mac.html>，轻仪卡片跳独立官网。
- 安装 /Applications/LiteGauge.app（0.4.3 (10)），普通模式运行；后台启用，正常关闭浏览器许可已开启。升级用 `bash scripts/install.sh --restart`；CLI `~/.local/bin/litegauge` 链到包内主程序，project.yaml 以 sop.cli 声明。Stats 的安装、运行与登录项保留。
- 源目录 ~/Apps/litegauge（2026-09-27 由 tlstats 改名），登记 id/family 为 litegauge。

## 发行与验证

当前公开发布 0.4.1，本机装机 0.4.3 (10)，bundle cyou.tianli.litegauge，Apple Silicon / macOS 14+，中文界面。已安装构建来源与 SHA256 见本页顶部及 perf/build-receipt.json；公开发布元数据仍以 release/latest.json 为准。0.3.0 历史构建来源 bfc9edc，ZIP 1,909,034 bytes、DMG 1,967,263 bytes；0.2.0 历史构建来源 5b8e39c，ZIP 1,851,270 bytes、DMG 2,191,584 bytes，均曾 Developer ID 签名、公证。

历史：0.1.0 (1) ZIP 1,626,948 bytes，DMG 2,129,632 bytes，可执行 SHA256 5f86b966…。perf/build-receipt.json 包围实际 bash scripts/package-release.sh 构建生成；独立解包、Gatekeeper、公证票据、DMG 内容、CLI JSON/错误码、干净源码副本构建已验；核心测试和 GitHub CI 通过。未在真实 macOS 14 设备运行。

注意 bash build.sh 会覆盖 build/LiteGauge.app 为 ad-hoc 本机包。app_sop build-receipt 会真正执行传入命令；发行包必须传实际签名公证构建，不能给旧包填来源。

## 实测

最新正式实测为 0.1.2 (3)，2026-10-01：安装包 1.7 MB / 装后 1.9 MB、内存 15.7 MB、空闲 CPU 0%、首个 CPU 读数 1.2 s。0.3.0 待符合条件的空闲重测，官网明确标注上述数据属于历史版本。唯一事实源为 perf/lightweight.json。以下为 0.1.0 首测记录：

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
- 收尾：`accept --all` 9 项 passed（含 cli_entry），check-only 仅剩 promo.card：apps.tianli.cyou 目录卡片仍显示 0.1.0 数字，需门户组件 apps-portal 用 `bash ~/Apps/apps-portal/site/deploy.sh` 重新部署（本组件以外，未做）。

## 2026-09-29 facts.json 上线

- 另一会话提交 757c0d1：build-site.py 从本产品 perf/lightweight.json 与 release 记录生成站点根 facts.json，门户卡片与 Chapter 读取它。本轮按授权 `bash scripts/deploy-site.sh` 重新部署，verify-site 含 facts.json 逐文件通过；线上 facts.json 为 0.1.1 (2)：安装包 1.6 MB / 装后 1.9 MB、内存 24.1 MB、CPU 0.98%、速度 1.2 s。以后重测只需重新部署本主页，门户卡片随之更新。

## 2026-09-30 面向 agent 的命令行

- 目标（本人原则「GUI 给人，CLI 给 agent」）：菜单栏里能看、能做的都能经 `litegauge` 驱动；GUI、CLI 共用 Sources/Metrics.swift，不另写实现。
- 新增：`watch [--interval <秒>] [--count <次>] [--json]`（一个 sampler、1 秒 CPU 预热，之后按 2 秒默认节奏，磁盘沿用 60 秒缓存，NDJSON 每行一次 write；SIGINT/SIGTERM 干净结束）；`app status [--json]`（NSRunningApplication 按 bundle id 列实例、排除自身 pid，经 ~/.local/bin 软链调用时从解析后的可执行文件反推所在 .app）；`app quit (--dry-run | --yes) [--json]`（SIGTERM 后最多等 5 秒，沿 0.1.1 装机时实际用过的 TERM 路径；不带确认参数退出 2）；`--version --json`；`-h`/`help`/`<子命令> --help` 退出 0；`--help` 列开发参数；经小写 `litegauge` 不带参数只打印用法、退出 2（大写包内路径、LaunchServices、`--background`/`--benchmark` 行为不变）。
- `status --json` 只加键：`ok`、`memory.percent/pressureLevel/level`、`disk.usedPercent/level/warnAbovePercent/mountPoint`、`errorCodes`；原 `pressure`、`volume`、`errors` 保留，缺失读数写 null。模型改为 Encodable + 自定义 encode；MemoryReading 保留 `pressure:` 标签初始化器，scripts/capture/main.swift 夹具照常编译。
- 共享判断：PressureLevel、MetricLevel、MetricThresholds.diskWarnPercent=90、MetricsSampler.sampleInterval、MetricFormat.cadence、AppIdentity.bundleID；App.swift 面板配色、计时器、底部说明、单实例保护（RunningInstances.others()）改读这些。18 个面板夹具（4 种压力 × 磁盘 50/90/90.1/90.5%、错误态、空态）新旧源码离屏渲染逐字节相同，docs/media/manifest.json 记 `reused_for: 0.1.1` 及依据，录像不必重录。
- 验证：`bash build.sh --test-only` 43 项通过（新增等级/阈值/JSON/参数解析/watch 流式与停止；阈值改 95、短命令改回启动 GUI 两个变异均被测试拦下）；`bash build.sh` 产出 build/LiteGauge.app（未装机）；functionality（14/14，新增 JSON 字段、watch、app status 对 ps、短命令用法）、privacy 8/8、native_ui 12/12 通过。recovery.sh 未跑：它在已有实例时会启动一个重复 GUI 进程（本轮禁止启动 GUI），其非法参数部分已手工核对（均退出 2、stdout 为空）。cli_entry 以 sop.cli 声明对已装 0.1.1 通过，链接缺失时判失败（退出 1，不再是 78）。
- 独立复核后修正：① `--help`/`-h` 出现在任何位置都只显示帮助——此前 `--benchmark --help` 会启动测试菜单栏实例并把 ready_ms 写进名为 `--help` 的文件，`--snapshot -h`、`--ui-self-test --help` 会写文件；② `app status`/`app quit` 改用 `RunningInstances.menuBar()`（`.accessory` 且 `isFinishedLaunching`），离屏自检、渲染进程不再被列出或退出——探针实测自检进程启动后前 2–4 次采样仍是 `.accessory` 但从未完成启动，单实例保护仍用 `others()` 不变；③ `app quit` 加 `--pid <pid>`，只退出指定实例；SIGTERM 与等待逻辑移入 CLI.swift `CLIProcess.terminate`，核心测试在真实子进程上验证（正常退出、TERM 被屏蔽时到时报告仍在运行、已退出 pid 幂等）；④ `--version`（含 `--json`）与 `app status` 的 cli 版本、构建号都读自所在 App 的 Info.plist，核心测试把 `version` 常量钉到 Info.plist；⑤ 两份 README 补「-h/help/命令后 --help、不带参数只打印用法」也是 0.1.1 之后的变化。
- 复核后验证：核心测试 48 项通过（变异：还原旧 help 判断、版本常量改 0.1.2、不发 SIGTERM、去掉子进程回收、允许 `--pid 0` 均被拦下）；连跑 5 次均通过；build/LiteGauge.app 可执行文件 300,704 字节；16 种 help 写法（含 4 个开发参数后加 --help）全部退出 0、无文件写出、无新进程；19 种参数错误退出 2；5 轮离屏自检期间 195 次轮询，`app status` 与 `app quit --dry-run` 均未列出自检进程，常驻 13299 始终列出、启动时间不变；functionality 14/14、native_ui 12/12、privacy 8/8。
- 未实测：`app quit --yes` 对真实菜单栏实例（会移除本人的菜单栏图标）；只验了 `--dry-run`（含 `--pid`）、拒绝路径和核心测试里对子进程的 SIGTERM 路径。授权窗口里可先 `LiteGauge --benchmark <文件>` 起测试实例，再 `litegauge app quit --yes --pid <测试 pid>` 实测并回读 `app status`，不碰常驻实例。
- 待发版：已装 0.1.1 不含新命令。发 0.1.2 时改 Info.plist、Sources/CLI.swift 的 `version`（两者不一致时核心测试失败）、scripts/capture-media.sh 清单版本、README 下载文件名与「0.1.1 之后加入」一句、CHANGELOG「未发布」标题、manifest reused_for 键；随后 package-release → 装机（可先 `litegauge app quit --yes`，再 `open -g -j`）→ 空闲 perf 重测 → deploy-site。

## 2026-10-01 发布 0.1.2 (3) 并装机（Chapter 修复轮，本人长期授权）

- 版本：Info.plist 0.1.2 / build 3、CLI.swift `version`、README 下载文件名与「自 0.1.2 起」说明、CHANGELOG、release-notes、manifest `reused_for.0.1.2`（App.swift/Metrics.swift 自 0.1.1 沿用核对后未变）；capture-media.sh 改从 Info.plist 读版本，不再手改（1d780db）。
- `chapter sop build-receipt ... --build-command "bash scripts/package-release.sh"`（receipt 的 6 个 glob）：App 与 DMG 公证 Accepted（e50d750e…、e29f0441…），receipt commit 1d780db、dirty=false，可执行 66ed618b…。独立解包 ZIP：可执行哈希一致、stapler/spctl 通过。
- install.sh 新增升级路径：已装时把旧包移到 `~/.Trash/litegauge-<旧版本>-<时间>/`；已装实例在运行时须 `--restart`，由新包自己的 `app quit --yes --pid` 退出（只退出 /Applications 那份菜单栏实例），替换后 `open -g -j` 后台重启；复制/校验失败放回旧包。CLI 软链已存在且指向本 App 时保留，指向别处则拒绝。实跑：退出 13299（0.1.1）→ 旧包在 ~/.Trash/litegauge-0.1.1-20261001-103726/ → 新实例 64459 为 0.1.2 (3)，可执行哈希与 receipt 一致。这也是 `app quit --yes` 第一次对真实菜单栏实例实测。
- 推送 46c5e54..4c9f64d（含上轮未推的 agent CLI 两个提交；触发 Core tests CI）；GitHub Release v0.1.2 为 Latest，target 4c9f64d，ZIP/DMG 下载哈希与 SHA256SUMS 一致。
- `chapter sop accept --app litegauge --all`：10 项全部 passed，installed_icon 由 builtin 离屏 IconServices 比对判定（256px 均差 5.3、512px 均差 7.42），不再需要本人确认。
- 未做：perf 重测（本轮禁止测量，留给后续统一测量阶段）；官网部署依赖它——build-site.py 在 release 与 perf 版本不一致时拒绝生成，所以官网/facts.json 仍是 0.1.1 数字与 0.1.1 下载（v0.1.1 资产仍在，链接有效）。测量后：README 数字块 → `python3 scripts/build-site.py && bash scripts/deploy-site.sh`。
