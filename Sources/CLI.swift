import Foundation

// Command-line surface for agents and scripts. Foundation only, so the core tests compile it without AppKit.
// Readings come from the same MetricsSampler / MetricFormat / MetricThresholds the menu-bar App draws from.

let version = "0.4.3"

struct WatchOptions: Equatable {
    var interval: TimeInterval = MetricsSampler.sampleInterval
    var count: Int? = nil
    var json = false
}

enum CLICommand: Equatable {
    case help
    case usage                       // `litegauge` with no arguments: print usage, never start the menu-bar App
    case version(json: Bool)
    case status(json: Bool)
    case diagnose(json: Bool, sort: DiagnosticSort, limit: Int)
    case processAction(json: Bool, dryRun: Bool, action: String, pid: Int32, token: String)
    case care(operation: String, json: Bool, dryRun: Bool)
    case watch(WatchOptions)
    case appStatus(json: Bool)
    case appQuit(json: Bool, dryRun: Bool, pid: Int32?)
    case gui(benchmark: String?)     // no arguments via the bundle executable, --background, --benchmark <file>
    case snapshot(path: String)
    case uiSelfTest(dir: String?)
}

struct CLIUsageError: Error, Equatable {
    let message: String
}

enum CLI {
    static let shortName = "litegauge"
    static let watchIntervalRange: ClosedRange<TimeInterval> = 1...3600

    static let helpText = """
    轻仪 LiteGauge \(version) — 极简 CPU / 内存 / 磁盘监控（菜单栏 App 与命令行共用同一采集层）

    用法：
      litegauge status [--json]
          采样约 1 秒，输出一次 CPU、内存、启动磁盘读数。
      litegauge diagnose [--sort memory|cpu] [--limit 1..50] [--json]
          按需扫描并合并应用进程，报告内存压力、主要占用与建议；CPU 的 100% 表示一个核心。
      litegauge process quit|restart --pid <pid> --token <诊断中的token> (--dry-run | --yes) [--json]
          正常退出或受控重启所选应用，核对进程身份，完成后复查占用；不强制结束系统进程。
      litegauge care plan|status [--json]
          汇总具体操作建议，或查看自动处理策略与最近结果，不需要逐个选择进程。
      litegauge care enable --yes [--json] | care disable [--json]
          一次允许/暂停 Shadowrocket、OrbStack 的后台自动处理。隧道/容器可能短暂中断，aTrust 和工作应用保留。
      litegauge care browsers (--yes | --disable) [--json]
          另行允许正常关闭 Dia / Chrome 并保持关闭；下载和页面任务会中断，保存提示由浏览器处理。
      litegauge care run (--dry-run | --yes) [--json]
          主动关闭已允许的 Dia / Chrome，不再打开，也不受浏览器内存阈值限制；异常后台服务正常恢复。逐项复查真实占用。
      litegauge watch [--interval <秒>] [--count <次数>] [--json]
          按 App 的节奏持续输出：默认每 \(Int(MetricsSampler.sampleInterval)) 秒（1–3600），磁盘容量缓存 \(Int(MetricsSampler.diskInterval)) 秒；
          --json 时每行一个 JSON 对象（NDJSON）。次数到达或 Ctrl-C 后结束。
      litegauge app status [--json]
          菜单栏实例是否在运行：pid、bundle 路径与版本。只读；离屏自检、渲染等验收进程不计入。
      litegauge app quit (--dry-run | --yes) [--pid <pid>] [--json]
          退出运行中的菜单栏实例（与菜单 ⌘Q 结果相同，发送 SIGTERM，最多等 5 秒）。
          --dry-run 只列出将退出的实例；--yes 才实际执行；--pid 只退出该 pid 的实例。
      litegauge --version [--json]
      litegauge --help | -h | help（任一命令或参数后加 --help / -h 也只显示本帮助，不执行）

    开发与验收参数：
      --ui-self-test [目录]   离屏自检真实菜单、面板和指示图标；stdout 输出一行 JSON，PNG 写入目录（缺省为临时目录）。
      --snapshot <png>        把详情面板渲染成 PNG。
      --benchmark <文件>      启动测试用菜单栏实例（跳过单实例检查、不自行退出），首个 CPU 读数后写入 ready_ms JSON。
      --background            启动菜单栏 App（Chapter 实测使用）。

    经 litegauge 短命令不带参数时只打印用法并退出 2，不会启动菜单栏 App；
    从「应用程序」打开，或 open -g -j /Applications/LiteGauge.app。
    退出码：0 成功；1 采集失败或操作未完成；2 参数错误。
    """

    static let usageText = """
    用法：litegauge status [--json] | care plan|status|enable|disable|browsers|run [--json] | diagnose [--sort memory|cpu] [--limit 1..50] [--json] | process quit|restart --pid <pid> --token <token> (--dry-run | --yes) | watch [--interval <秒>] [--count <次数>] [--json] | app status [--json] | app quit (--dry-run | --yes) [--pid <pid>] [--json] | --version | --help
    litegauge 不带参数不会启动菜单栏 App；从「应用程序」打开，或 open -g -j /Applications/LiteGauge.app。
    """

    static func parse(_ args: [String], invokedAs: String) -> Result<CLICommand, CLIUsageError> {
        let helpFlags: Set<String> = ["--help", "-h"]
        guard let first = args.first else {
            let name = (invokedAs as NSString).lastPathComponent
            return .success(name == shortName ? .usage : .gui(benchmark: nil))
        }
        // --help / -h anywhere wins, so asking for help never runs an action (dev flags included).
        if first == "help" || args.contains(where: helpFlags.contains) { return .success(.help) }
        let rest = Array(args.dropFirst())
        switch first {
        case "--version":
            return options(rest, switches: ["--json"]).map { .version(json: $0["--json"] != nil) }
        case "status":
            return options(rest, switches: ["--json"]).map { .status(json: $0["--json"] != nil) }
        case "diagnose":
            return options(rest, switches: ["--json"], valued: ["--sort", "--limit"]).flatMap { found in
                guard let sort = DiagnosticSort(rawValue: found["--sort"] ?? "memory"),
                      let limit = Int(found["--limit"] ?? "10"), (1...50).contains(limit) else {
                    return fail("diagnose 的 --sort 须为 memory 或 cpu，--limit 须为 1 到 50")
                }
                return .success(.diagnose(json: found["--json"] != nil, sort: sort, limit: limit))
            }
        case "care":
            guard let operation = rest.first, ["plan", "status", "enable", "disable", "browsers", "run"].contains(operation) else { return fail("care 需要 plan、status、enable、disable、browsers 或 run") }
            let switches: Set<String> = operation == "run" ? ["--json", "--yes", "--dry-run"] : operation == "browsers" ? ["--json", "--yes", "--disable"] : operation == "enable" ? ["--json", "--yes"] : ["--json"]
            return options(Array(rest.dropFirst()), switches: switches).flatMap { found in
                if operation == "enable" && found["--yes"] == nil { return fail("开启后台自动处理须加 --yes；允许已列明的短暂隧道/容器中断") }
                if operation == "browsers" && ((found["--yes"] != nil) == (found["--disable"] != nil)) { return fail("关闭浏览器需要 --yes 或 --disable；关闭后不再打开，下载和页面任务会中断") }
                if operation == "run" && ((found["--yes"] != nil) == (found["--dry-run"] != nil)) { return fail("care run 需要 --dry-run 或 --yes，任选一个") }
                return .success(.care(operation: found["--disable"] != nil ? "retain-browsers" : operation, json: found["--json"] != nil, dryRun: found["--dry-run"] != nil))
            }
        case "process":
            guard let action = rest.first, ["quit", "restart"].contains(action) else { return fail("process 需要子命令 quit 或 restart") }
            return options(Array(rest.dropFirst()), switches: ["--json", "--yes", "--dry-run"], valued: ["--pid", "--token"]).flatMap { found in
                let dry = found["--dry-run"] != nil, yes = found["--yes"] != nil
                guard dry != yes, let raw = found["--pid"], let pid = Int32(raw), pid > 1,
                      let token = found["--token"], ProcessIdentity.validToken(token, pid: pid) else {
                    return fail("process 需要 --pid、诊断中的 --token，以及 --dry-run 或 --yes（任选一个）")
                }
                return .success(.processAction(json: found["--json"] != nil, dryRun: dry, action: action, pid: pid, token: token))
            }
        case "watch":
            return options(rest, switches: ["--json"], valued: ["--interval", "--count"]).flatMap(watchOptions)
        case "app":
            guard let action = rest.first else { return fail("app 需要子命令：status 或 quit") }
            let flags = Array(rest.dropFirst())
            switch action {
            case "status":
                return options(flags, switches: ["--json"]).map { .appStatus(json: $0["--json"] != nil) }
            case "quit":
                return options(flags, switches: ["--json", "--dry-run", "--yes"], valued: ["--pid"]).flatMap { found -> Result<CLICommand, CLIUsageError> in
                    let dryRun = found["--dry-run"] != nil, confirmed = found["--yes"] != nil
                    if dryRun && confirmed { return fail("--dry-run 与 --yes 只能选一个") }
                    if !dryRun && !confirmed { return fail("app quit 会移除菜单栏图标：加 --yes 确认，或加 --dry-run 只查看") }
                    var pid: Int32?
                    if let raw = found["--pid"] {
                        guard let value = Int32(raw), value > 0 else { return fail("--pid 须为正整数（现为 \(raw)）") }
                        pid = value
                    }
                    return .success(.appQuit(json: found["--json"] != nil, dryRun: dryRun, pid: pid))
                }
            default:
                return fail("未知的 app 子命令：\(action)（可用 status、quit）")
            }
        case "--snapshot":
            return rest.count == 1 ? .success(.snapshot(path: rest[0])) : fail("--snapshot 需要一个 PNG 路径")
        case "--ui-self-test":
            return rest.count <= 1 ? .success(.uiSelfTest(dir: rest.first)) : fail("--ui-self-test 最多接受一个目录")
        case "--background":
            return rest.isEmpty ? .success(.gui(benchmark: nil)) : fail("--background 不接受其他参数")
        case "--benchmark":
            return rest.count == 1 ? .success(.gui(benchmark: rest[0])) : fail("--benchmark 需要一个输出文件路径")
        default:
            return fail("未知参数：\(first)")
        }
    }

    private static func fail(_ message: String) -> Result<CLICommand, CLIUsageError> {
        .failure(CLIUsageError(message: message))
    }

    /// Flags as `--name` or `--name value` / `--name=value`. Unknown or repeated flags are usage errors.
    private static func options(_ args: [String], switches: Set<String>, valued: Set<String> = [])
        -> Result<[String: String], CLIUsageError> {
        var found: [String: String] = [:]
        var index = 0
        while index < args.count {
            var name = args[index], value: String?
            if let eq = name.firstIndex(of: "="), name.hasPrefix("--") {
                value = String(name[name.index(after: eq)...])
                name = String(name[..<eq])
            }
            if found[name] != nil { return .failure(CLIUsageError(message: "重复的参数：\(name)")) }
            if switches.contains(name), value == nil {
                found[name] = ""
            } else if valued.contains(name) {
                if value == nil {
                    guard index + 1 < args.count else { return .failure(CLIUsageError(message: "\(name) 需要一个值")) }
                    index += 1
                    value = args[index]
                }
                found[name] = value
            } else {
                return .failure(CLIUsageError(message: "未知参数：\(args[index])"))
            }
            index += 1
        }
        return .success(found)
    }

    private static func watchOptions(_ found: [String: String]) -> Result<CLICommand, CLIUsageError> {
        var options = WatchOptions(json: found["--json"] != nil)
        if let raw = found["--interval"] {
            guard let value = TimeInterval(raw), value.isFinite, watchIntervalRange.contains(value) else {
                return fail("--interval 须为 1 到 3600 之间的秒数（现为 \(raw)）")
            }
            options.interval = value
        }
        if let raw = found["--count"] {
            guard let value = Int(raw), value >= 1 else { return fail("--count 须为正整数（现为 \(raw)）") }
            options.count = value
        }
        return .success(.watch(options))
    }
}

// MARK: - Output

enum CLIOutput {
    static func json<T: Encodable>(_ value: T, pretty: Bool) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
    }

    /// One unbuffered write per call, so streamed lines reach pipes whole and in order.
    static func write(_ text: String, to handle: FileHandle = .standardOutput) {
        handle.write(Data(text.utf8))
    }

    static func statusLines(_ s: MetricsSnapshot) -> [String] {
        var lines = [MetricFormat.status(s)]
        if let m = s.memory {
            lines.append("内存 \(MetricFormat.gib(m.usedBytes)) / \(MetricFormat.gib(m.totalBytes)) · 压力\(m.pressure) · 交换 \(m.swapUsedBytes.map(MetricFormat.gib) ?? "—")")
        }
        if let d = s.disk {
            let warn = d.level == .warning ? " · 已用超过 \(Int(MetricThresholds.diskWarnPercent))%" : ""
            lines.append("磁盘剩余 \(MetricFormat.gb(d.availableBytes)) / \(MetricFormat.gb(d.totalBytes))\(warn)")
        }
        return lines
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func watchLine(_ s: MetricsSnapshot) -> String {
        let errors = s.errors.isEmpty ? "" : "  · " + s.errors.joined(separator: " · ")
        return "\(clock.string(from: s.sampledAt))  \(MetricFormat.status(s))\(errors)\n"
    }
}

// MARK: - Quitting

enum CLIProcess {
    /// SIGTERM each pid, then wait up to `timeout` for all of them to exit. A pid that is already gone is not an
    /// error. Returns the pids still alive at the deadline and any signal errors. Used by `app quit --yes`.
    static func terminate(_ pids: [pid_t], timeout: TimeInterval = 5) -> (stillRunning: [pid_t], errors: [String]) {
        var errors: [String] = []
        for pid in pids where kill(pid, SIGTERM) != 0 && errno != ESRCH {   // ESRCH: already gone
            errors.append("pid \(pid): \(String(cString: strerror(errno)))")
        }
        let deadline = Date().addingTimeInterval(timeout)
        var still = pids.filter(isAlive)
        while !still.isEmpty && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            still = still.filter(isAlive)
        }
        return (still, errors)
    }

    /// Alive = the pid exists (EPERM also means it exists). A child of this process that has exited is reaped first,
    /// so it does not linger as a zombie; for any other pid waitpid just fails with ECHILD.
    static func isAlive(_ pid: pid_t) -> Bool {
        if waitpid(pid, nil, WNOHANG) == pid { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}

// MARK: - Sampling commands

enum CLISampling {
    /// A fresh reading with a CPU baseline: first sample, wait, second sample (disk read on the first).
    static func freshSnapshot(warmup: TimeInterval = 1) -> MetricsSnapshot {
        let sampler = MetricsSampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: warmup)
        return sampler.sample()
    }

    /// Streams readings at the App's cadence from one sampler (disk cached for diskInterval, like the App).
    /// Stops after `count` records or when `stop` is signalled. Returns the exit code: 1 if any record had errors.
    static func watch(_ options: WatchOptions, stop: DispatchSemaphore, warmup: TimeInterval = 1,
                      emit: (String) -> Void) throws -> Int32 {
        let sampler = MetricsSampler()
        _ = sampler.sample()
        if stop.wait(timeout: .now() + warmup) == .success { return 0 }
        let start = ProcessInfo.processInfo.systemUptime
        var emitted = 0, failed = false
        while true {
            let snapshot = sampler.sample()
            failed = failed || !snapshot.ok
            let line = try options.json ? CLIOutput.json(snapshot, pretty: false) : CLIOutput.watchLine(snapshot)
            emit(line)
            emitted += 1
            if let count = options.count, emitted >= count { break }
            let next = start + Double(emitted) * options.interval
            let wait = max(0, next - ProcessInfo.processInfo.systemUptime)
            if stop.wait(timeout: .now() + wait) == .success { break }
        }
        return failed ? 1 : 0
    }

    /// SIGINT/SIGTERM signal the returned semaphore instead of killing the process mid-line.
    static func stopOnSignals() -> (DispatchSemaphore, [DispatchSourceSignal]) {
        let stop = DispatchSemaphore(value: 0)
        let sources = [SIGINT, SIGTERM].map { number -> DispatchSourceSignal in
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .global(qos: .utility))
            source.setEventHandler { stop.signal() }
            source.resume()
            return source
        }
        return (stop, sources)
    }
}
