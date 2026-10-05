import AppKit

// Entry point for both the menu-bar App and the `litegauge` command line. Parsing, help and readings live in
// CLI.swift / Metrics.swift; this file only dispatches and adds the AppKit-backed `app` commands.

func fail(_ message: String, code: Int32) -> Never {
    CLIOutput.write(message + "\n", to: .standardError)
    exit(code)
}

func writeJSONObject(_ object: [String: Any]) {
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: options) else {
        fail("无法生成 JSON", code: 1)
    }
    CLIOutput.write(String(decoding: data, as: UTF8.self) + "\n")
}

func bundleInfo(_ url: URL?) -> (version: String?, build: String?) {
    guard let url, let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) else { return (nil, nil) }
    return (info["CFBundleShortVersionString"] as? String, info["CFBundleVersion"] as? String)
}

func resolved(_ url: URL?) -> String? { url?.resolvingSymlinksInPath().standardizedFileURL.path }

/// The .app containing this executable. Called through the ~/.local/bin symlink, Bundle.main points at the
/// symlink's directory instead, so resolve the executable and walk up Contents/MacOS.
let hostBundleURL: URL? = {
    guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
    let app = exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return app.pathExtension == "app" ? app : nil
}()

func describe(_ app: NSRunningApplication) -> [String: Any] {
    let (appVersion, build) = bundleInfo(app.bundleURL)
    let launched = app.launchDate.map { ISO8601DateFormatter().string(from: $0) }
    return ["pid": Int(app.processIdentifier), "bundlePath": resolved(app.bundleURL) ?? NSNull(),
            "executablePath": resolved(app.executableURL) ?? NSNull(), "version": appVersion ?? NSNull(),
            "build": build ?? NSNull(), "launchedAt": launched ?? NSNull(),
            "sameBundleAsCLI": resolved(app.bundleURL) == resolved(hostBundleURL)]
}

func instanceLine(_ info: [String: Any]) -> String {
    let path = info["bundlePath"] as? String ?? "?", v = info["version"] as? String ?? "?", b = info["build"] as? String ?? "?"
    return "pid \(info["pid"] ?? "?") · \(path) · \(v) (\(b))"
}

/// Version and build of the running executable, both from its bundle's Info.plist so they never mix sources;
/// the `version` constant is only the fallback outside a bundle (a core test pins it to Info.plist).
func cliVersion() -> (version: String, build: String?) {
    let info = bundleInfo(hostBundleURL)
    return (info.version ?? version, info.build)
}

func appStatus(json: Bool) {
    let instances = RunningInstances.menuBar().map(describe)
    let current = cliVersion()
    let cli: [String: Any] = ["bundlePath": resolved(hostBundleURL) ?? NSNull(),
                              "executablePath": resolved(Bundle.main.executableURL) ?? NSNull(),
                              "version": current.version, "build": current.build ?? NSNull()]
    if json {
        writeJSONObject(["ok": true, "bundleId": AppIdentity.bundleID, "running": !instances.isEmpty,
                         "instances": instances, "cli": cli])
        return
    }
    var lines = instances.isEmpty ? ["菜单栏实例：未运行"] : instances.map { "菜单栏实例运行中：" + instanceLine($0) }
    lines.append("命令行所在：\(cli["bundlePath"] as? String ?? "?") · \(current.version) (\(current.build ?? "?"))")
    CLIOutput.write(lines.joined(separator: "\n") + "\n")
}

/// Same outcome as the menu's ⌘Q: the menu-bar instance ends and its status item disappears. SIGTERM is the
/// path the 0.1.1 upgrade used; the App has no unsaved state (applicationWillTerminate only stops timers).
/// With `pid`, only that menu-bar instance is a target, so a test instance can be quit without touching another.
func appQuit(json: Bool, dryRun: Bool, pid: Int32?) -> Int32 {
    let running = RunningInstances.menuBar()
    let targets = pid.map { wanted in running.filter { $0.processIdentifier == wanted } } ?? running
    let described = targets.map(describe)
    var still: [pid_t] = []
    var signalErrors: [String] = []
    if !dryRun { (still, signalErrors) = CLIProcess.terminate(targets.map(\.processIdentifier)) }
    let ok = still.isEmpty && signalErrors.isEmpty
    if json {
        writeJSONObject(["ok": ok, "dryRun": dryRun, "bundleId": AppIdentity.bundleID, "pid": pid.map { Int($0) } ?? NSNull(),
                         "targets": described, "stillRunning": still.map { Int($0) }, "errors": signalErrors])
    } else if targets.isEmpty {
        CLIOutput.write(pid.map { "pid \($0) 不是运行中的菜单栏实例，无需退出。\n" } ?? "菜单栏实例未运行，无需退出。\n")
    } else if dryRun {
        CLIOutput.write((["将退出："] + described.map(instanceLine)).joined(separator: "\n  ") + "\n")
    } else if ok {
        CLIOutput.write((["已退出："] + described.map(instanceLine)).joined(separator: "\n  ") + "\n")
    } else {
        CLIOutput.write("未能在 5 秒内退出：pid \(still.map(String.init).joined(separator: ", "))\n"
                        + signalErrors.map { $0 + "\n" }.joined(), to: .standardError)
    }
    return ok ? 0 : 1
}

let command: CLICommand
switch CLI.parse(Array(CommandLine.arguments.dropFirst()), invokedAs: CommandLine.arguments.first ?? "") {
case .success(let parsed): command = parsed
case .failure(let error): fail("\(error.message)；用 --help 查看用法。", code: 2)
}

switch command {
case .help:
    CLIOutput.write(CLI.helpText + "\n")
case .usage:
    fail(CLI.usageText, code: 2)
case .version(let json):
    let current = cliVersion()
    if json {
        writeJSONObject(["ok": true, "name": "LiteGauge", "version": current.version, "build": current.build ?? NSNull()])
    } else {
        CLIOutput.write("LiteGauge \(current.version)\n")
    }
case .status(let json):
    let snapshot = CLISampling.freshSnapshot()
    if json {
        CLIOutput.write(try CLIOutput.json(snapshot, pretty: true))
    } else {
        CLIOutput.write(CLIOutput.statusLines(snapshot).joined(separator: "\n") + "\n")
        if !snapshot.ok { CLIOutput.write(snapshot.errors.joined(separator: "\n") + "\n", to: .standardError) }
    }
    exit(snapshot.ok ? 0 : 1)
case .diagnose(let json, let sort, let limit):
    let result = ResourceDiagnostics.collect()
    let groups = Array(result.sorted(sort).prefix(limit))
    let recommendations = try? CareRuntime.preview(result)
    if json {
        // Preserve complete coverage metadata while returning only the requested ranking.
        var object = (try JSONSerialization.jsonObject(with: Data(CLIOutput.json(result, pretty: false).utf8))) as! [String: Any]
        object["groups"] = try JSONSerialization.jsonObject(with: Data(CLIOutput.json(groups, pretty: false).utf8))
        object["sort"] = sort.rawValue; object["limit"] = limit
        if let recommendations { object["recommendations"] = try JSONSerialization.jsonObject(with: Data(CLIOutput.json(recommendations, pretty: false).utf8)) }
        writeJSONObject(object)
    } else {
        var lines = CLIOutput.statusLines(result.system)
        lines.append("应用 / 进程\t内存计账\tCPU（100%=单核）\t进程数")
        lines += groups.map { "\($0.name)\t\(DiagnosticFormat.memory($0))\t\(DiagnosticFormat.cpu($0))\t\($0.processes.count)" }
        lines += result.advice
        lines += recommendations?.lines ?? ["操作策略不可读，自动处理已暂停。"]
        lines.append("身份不可读 \(result.unreadableIdentityCount) 个 · \(result.memoryAccounting)")
        CLIOutput.write(lines.joined(separator: "\n") + "\n")
    }
    exit(result.ok ? 0 : 1)
case .processAction(let json, let dryRun, let action, let pid, let token):
    let result = ResourceActions.perform(pid: pid, token: token, action: action, dryRun: dryRun)
    if json { CLIOutput.write(try CLIOutput.json(result, pretty: true)) }
    else { CLIOutput.write(result.message + "\n", to: result.ok ? .standardOutput : .standardError) }
    exit(result.ok ? 0 : 1)
case .care(let operation, let json, let dryRun):
    do {
        let store = CareStore()
        switch operation {
        case "retain-browsers":
            try store.retainBrowsers()
            if json { CLIOutput.write(try CLIOutput.json(store.policy(), pretty: true)) }
            else { CLIOutput.write("已暂停浏览器恢复，保留其余后台处理策略。\n") }
        case "browsers":
            try store.allowBrowsers()
            if json { CLIOutput.write(try CLIOutput.json(store.policy(), pretty: true)) }
            else { CLIOutput.write("已允许 Dia / Chrome 空闲时恢复重启，并保留原后台处理；无痕页面、表单和下载不保证恢复。\n") }
        case "enable", "disable":
            try store.setEnabled(operation == "enable")
            let policy = try store.policy()
            if json { CLIOutput.write(try CLIOutput.json(policy, pretty: true)) }
            else { CLIOutput.write(policy.enabled ? "已开启后台自动处理：Shadowrocket / OrbStack；aTrust 和工作应用保留。\n" : "已暂停后台自动处理。\n") }
        case "status":
            if json { writeJSONObject(["ok": true, "policy": try JSONSerialization.jsonObject(with: Data(CLIOutput.json(store.policy(), pretty: false).utf8)), "history": try JSONSerialization.jsonObject(with: Data(CLIOutput.json(store.journal(), pretty: false).utf8))]) }
            else { CLIOutput.write("自动处理\(try store.policy().enabled ? "已开启" : "未开启")\n\(try store.journal().summary)\n") }
        case "plan":
            let report = try CareRuntime.preview(ResourceDiagnostics.collect())
            if json { CLIOutput.write(try CLIOutput.json(report, pretty: true)) }
            else { CLIOutput.write(report.lines.joined(separator: "\n") + "\n") }
        default:
            let result = try CareRuntime.run(batch: true, dryRun: dryRun)
            if json { CLIOutput.write(try CLIOutput.json(result, pretty: true)) }
            else { CLIOutput.write(result.report.lines.joined(separator: "\n") + "\n" + result.message + "\n") }
            exit(result.ok ? 0 : 1)
        }
    } catch {
        let message = (error as? ResourceActionError)?.message ?? error.localizedDescription
        if json { writeJSONObject(["ok": false, "message": message]) } else { CLIOutput.write(message + "\n", to: .standardError) }
        exit(1)
    }
case .watch(let options):
    let (stop, sources) = CLISampling.stopOnSignals()
    let code = try CLISampling.watch(options, stop: stop) { CLIOutput.write($0) }
    withExtendedLifetime(sources) {}
    exit(code)
case .appStatus(let json):
    appStatus(json: json)
case .appQuit(let json, let dryRun, let pid):
    exit(appQuit(json: json, dryRun: dryRun, pid: pid))
case .snapshot(let path):
    NSApplication.shared.setActivationPolicy(.prohibited)
    try renderSnapshot(to: path)
case .uiSelfTest(let dir):
    NSApplication.shared.setActivationPolicy(.prohibited)
    let out = URL(fileURLWithPath: dir ?? NSTemporaryDirectory(), isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    exit(AppDelegate(benchmark: nil).runUISelfTest(outDir: out) ? 0 : 1)
case .gui(let benchmark):
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate(benchmark: benchmark)
    app.delegate = delegate
    signal(SIGTERM, SIG_IGN)
    let terminateSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    terminateSignal.setEventHandler { delegate.requestQuit() }; terminateSignal.resume()
    app.run()
    terminateSignal.cancel()
    withExtendedLifetime(terminateSignal) {}
    withExtendedLifetime(delegate) {}
}
