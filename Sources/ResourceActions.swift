import AppKit
import SystemConfiguration

struct ResourceActionError: Error { let message: String }

struct ResourceActionPlan: Encodable {
    let action: String
    let kind: String
    let target: ProcessIdentity
    let bundlePath: String
    let name: String
    let warning: String
    let mainProcess: ProcessIdentity?
    let serviceID: String?
    let executable: String?
    var launchArguments: [String] = []
}

struct ResourceActionResult: Encodable {
    let ok: Bool
    let dryRun: Bool
    let status: String
    let message: String
    let plan: ResourceActionPlan?
    let beforeBytes: UInt64?
    let afterBytes: UInt64?
    var reducedBytes: UInt64? {
        guard let beforeBytes, let afterBytes else { return nil }
        return beforeBytes > afterBytes ? beforeBytes - afterBytes : 0
    }
    private enum CodingKeys: String, CodingKey { case ok, dryRun, status, message, plan, beforeBytes, afterBytes, reducedBytes }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok); try c.encode(dryRun, forKey: .dryRun)
        try c.encode(status, forKey: .status); try c.encode(message, forKey: .message); try c.encode(plan, forKey: .plan)
        try c.encode(beforeBytes, forKey: .beforeBytes); try c.encode(afterBytes, forKey: .afterBytes)
        try c.encode(reducedBytes, forKey: .reducedBytes)
    }
}

/// Explicit actions only. Each adapter uses the application's own shutdown or the OS connection API.
/// The opt-in care controller shares these adapters. No cache purges, forced termination or login-item changes.
enum ResourceActions {
    private final class OpenResult {
        private let lock = NSLock()
        private var complete = false
        private var errorText: String?
        func finish(_ error: Error?) {
            lock.lock(); defer { lock.unlock() }
            errorText = error?.localizedDescription; complete = true
        }
        var state: (Bool, String?) {
            lock.lock(); defer { lock.unlock() }
            return (complete, errorText)
        }
    }
    static func prepare(pid: Int32, token: String, action: String) throws -> ResourceActionPlan {
        guard ["quit", "restart"].contains(action), let (identity, _) = NativeProcessReader.identity(pid),
              identity.token == token, identity.userID == getuid(), pid != getpid(), pid > 1 else {
            throw ResourceActionError(message: "进程已变化、已退出或不属于当前用户；请重新诊断。")
        }
        guard !identity.executablePath.localizedCaseInsensitiveContains("atrust") else {
            throw ResourceActionError(message: "aTrust 按保留规则略过，不安排退出或重启。")
        }
        guard let bundlePath = ResourceDiagnostics.outerBundle(identity.executablePath),
              !bundlePath.hasPrefix("/System/"), let bundle = Bundle(path: bundlePath),
              let bundleID = bundle.bundleIdentifier, bundleID != AppIdentity.bundleID else {
            throw ResourceActionError(message: "系统进程、独立后台任务和轻仪自身只提供诊断；请在所属应用中处理。")
        }
        let name = (bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        if bundleID == "dev.kdrag0n.MacVirt" {
            guard action == "restart" else { throw ResourceActionError(message: "OrbStack 提供重启虚拟机后台；退出界面不会释放虚拟机内存。") }
            let tool = URL(fileURLWithPath: bundlePath).appendingPathComponent("Contents/MacOS/bin/orbctl").path
            guard FileManager.default.isExecutableFile(atPath: tool) else { throw ResourceActionError(message: "找不到 OrbStack 的官方 orbctl，无法执行受控重启。") }
            return ResourceActionPlan(action: action, kind: "orbstack", target: identity, bundlePath: bundlePath, name: name,
                warning: "将正常停止并启动 OrbStack 的虚拟机后台；容器和 Linux 任务会暂时中断，数据、镜像和设置保留。请先保存工作。",
                mainProcess: nil, serviceID: nil, executable: tool)
        }
        if bundleID == "com.liguangming.Shadowrocket" {
            guard action == "restart", let service = vpnService(bundleID: bundleID) else {
                throw ResourceActionError(message: "未找到唯一的 Shadowrocket 系统连接，无法重启隧道；请在其应用中处理。")
            }
            return ResourceActionPlan(action: action, kind: "vpn", target: identity, bundlePath: bundlePath, name: name,
                warning: "将断开并重新连接 Shadowrocket 隧道，网络会短暂中断；保留代理配置。", mainProcess: nil,
                serviceID: service, executable: nil)
        }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter {
            $0.bundleURL?.resolvingSymlinksInPath().path == URL(fileURLWithPath: bundlePath).resolvingSymlinksInPath().path
                && $0.activationPolicy == .regular && !$0.isTerminated
        }
        guard apps.count == 1, let app = apps.first, let (main, _) = NativeProcessReader.identity(app.processIdentifier),
              main.userID == getuid() else { throw ResourceActionError(message: "后台服务或多个应用实例只提供诊断；无法确定唯一可正常退出的应用。") }
        if let root = BrowserRecovery.root(bundleID: bundleID) {
            if action == "restart" { _ = try BrowserRecovery.sessionFiles(at: root) }
            return ResourceActionPlan(action: action, kind: "browser", target: identity, bundlePath: bundlePath, name: name,
                warning: action == "restart" ? "正常退出后请求恢复普通标签；页面会重新加载，下载和页面任务可能中断，无痕页面、未提交表单不保证恢复。先保留本地会话备份，不强制结束。" : "正常关闭浏览器并保持关闭；下载和页面任务会中断，保存或离开页面提示由浏览器处理，不强制结束。",
                mainProcess: main, serviceID: nil, executable: nil, launchArguments: action == "restart" ? ["--restore-last-session"] : [])
        }
        return ResourceActionPlan(action: action, kind: "application", target: identity, bundlePath: bundlePath, name: name,
            warning: action == "restart" ? "将正常退出并在后台重新打开应用；请先保存工作。浏览器是否恢复页面由其自身设置决定。"
                : "将正常退出应用；保存提示由应用处理，不会强制结束。",
            mainProcess: main, serviceID: nil, executable: nil)
    }

    static func vpnService(bundleID: String) -> String? {
        guard let prefs = SCPreferencesCreate(nil, "LiteGauge diagnosis" as CFString, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else { return nil }
        let matching = services.filter { service in
            guard let interface = SCNetworkServiceGetInterface(service) else { return false }
            let config = SCNetworkInterfaceGetConfiguration(interface) as? [String: Any] ?? [:]
            let extended = SCNetworkInterfaceGetExtendedConfiguration(interface, "VPN" as CFString) as? [String: Any] ?? [:]
            return [config, extended].contains { values in
                (values["VPNSubType"] as? String) == bundleID
                    || (values["NEProviderBundleIdentifier"] as? String)?.hasPrefix(bundleID + ".") == true
            }
        }
        guard matching.count == 1 else { return nil }
        return SCNetworkServiceGetServiceID(matching[0]) as String?
    }

    static func wait(_ seconds: Double, until predicate: () -> Bool) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while !predicate() && ProcessInfo.processInfo.systemUptime < deadline {
            if Thread.isMainThread { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
            else { Thread.sleep(forTimeInterval: 0.1) }
        }
        return predicate()
    }

    /// Bounded invocation of the bundled official CLI. Arguments never go through a shell.
    static func runTool(_ executable: String, _ arguments: [String], timeout: Double) throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: executable); child.arguments = arguments
        child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
        try child.run()
        guard wait(timeout, until: { !child.isRunning }) else {
            child.terminate()
            throw ResourceActionError(message: "官方命令执行超时；请在 OrbStack 中检查状态。")
        }
        guard child.terminationStatus == 0 else { throw ResourceActionError(message: "官方命令执行失败（\(child.terminationStatus)），请在 OrbStack 中检查状态。") }
    }

    static func footprint(bundlePath: String) -> UInt64? {
        let scan = NativeProcessReader.scan()
        guard scan.error == nil else { return nil }
        let rows = scan.observations.filter { ResourceDiagnostics.outerBundle($0.identity.executablePath) == bundlePath && $0.identity.userID == getuid() }
        guard rows.allSatisfy({ $0.footprintBytes != nil }) else { return nil }
        return rows.compactMap(\.footprintBytes).reduce(0, +)
    }

    static func perform(pid: Int32, token: String, action: String, dryRun: Bool, leaseOwned: Bool = false,
                        progress: (String) -> Void = { _ in }) -> ResourceActionResult {
        var plan: ResourceActionPlan?, before: UInt64?
        do {
            let p = try prepare(pid: pid, token: token, action: action); plan = p
            if dryRun { return ResourceActionResult(ok: true, dryRun: true, status: "preview", message: p.warning, plan: p, beforeBytes: nil, afterBytes: nil) }
            let lease = leaseOwned ? nil : try CareLease()
            defer { withExtendedLifetime(lease) {} }
            before = footprint(bundlePath: p.bundlePath)
            guard NativeProcessReader.identity(pid)?.0 == p.target else { throw ResourceActionError(message: "进程身份已经变化，请重新诊断。") }
            switch p.kind {
            case "orbstack":
                let tool = p.executable!
                let previousHelpers = NativeProcessReader.scan().observations.filter {
                    ResourceDiagnostics.outerBundle($0.identity.executablePath) == p.bundlePath
                        && $0.identity.userID == getuid()
                        && $0.identity.executablePath.contains("OrbStack Helper.app")
                }.map(\.identity)
                do { try runTool(tool, ["stop"], timeout: 35) }
                catch {
                    // A timeout can mean shutdown is still in progress. Attempt restoration even on failure.
                    do { try runTool(tool, ["start"], timeout: 35) }
                    catch { throw ResourceActionError(message: "停止和恢复命令均未完成；请在 OrbStack 检查并启动虚拟机后台。") }
                    throw ResourceActionError(message: "停止命令未完成，已执行恢复启动；无法确认重启完成，请在 OrbStack 检查状态。")
                }
                try runTool(tool, ["start"], timeout: 35)
                guard wait(20, until: {
                    NativeProcessReader.scan().observations.contains {
                        ResourceDiagnostics.outerBundle($0.identity.executablePath) == p.bundlePath
                            && $0.identity.userID == getuid()
                            && $0.identity.executablePath.contains("OrbStack Helper.app")
                            && !previousHelpers.contains($0.identity)
                    }
                }) else { throw ResourceActionError(message: "启动命令已执行，但虚拟机后台尚未就绪；请在 OrbStack 检查容器状态。") }
            case "vpn":
                guard let connection = SCNetworkConnectionCreateWithServiceID(nil, p.serviceID! as CFString, nil, nil),
                      SCNetworkConnectionGetStatus(connection) == .connected else {
                    throw ResourceActionError(message: "Shadowrocket 当前未连接，无需重启隧道。")
                }
                guard SCNetworkConnectionStop(connection, true) else { throw ResourceActionError(message: "系统拒绝断开连接：\(String(cString: SCErrorString(SCError())))") }
                let stopped = wait(15) { SCNetworkConnectionGetStatus(connection) == .disconnected }
                // Restore the connection even if shutdown took too long; never leave it intentionally stopped.
                guard SCNetworkConnectionStart(connection, nil, true) else { throw ResourceActionError(message: "重连请求失败，请在 Shadowrocket 重新连接。") }
                guard wait(30, until: { SCNetworkConnectionGetStatus(connection) == .connected }), stopped else {
                    throw ResourceActionError(message: "已发起重连，尚未确认完整断开和恢复；请查看 Shadowrocket 连接状态。")
                }
            default:
                let main = p.mainProcess!
                guard NativeProcessReader.identity(main.pid)?.0 == main,
                      let app = NSRunningApplication(processIdentifier: main.pid) else { throw ResourceActionError(message: "应用实例已变化，请重新诊断。") }
                if p.kind == "browser" && action == "restart" {
                    progress("\(p.name)：正在保留普通会话备份…")
                    guard let id = app.bundleIdentifier else { throw ResourceActionError(message: "浏览器身份不可读，已暂缓重启。") }
                    _ = try BrowserRecovery.backup(bundleID: id)
                }
                var accepted = false
                progress("\(p.name)：正在请求正常退出；保存或离开页面提示由浏览器处理…")
                if Thread.isMainThread { accepted = app.terminate() }
                else { DispatchQueue.main.sync { accepted = app.terminate() } }
                guard accepted else { throw ResourceActionError(message: "正常退出请求未被接受；本次操作未完成。") }
                guard wait(p.kind == "browser" ? 30 : 10, until: {
                    // An unreadable identity is not proof of exit; fall back to the original AppKit handle.
                    NativeProcessReader.identity(main.pid).map { $0.0 != main } ?? app.isTerminated
                }) else {
                    throw ResourceActionError(message: "正常退出未在等待时间内完成；如有保存或离开页面提示，浏览器仍在等待确认。本次操作未完成；未强制结束。")
                }
                if action == "restart" {
                    progress("\(p.name)：已确认原实例退出，正在恢复应用…")
                    let config = NSWorkspace.OpenConfiguration(); config.activates = false; config.hides = true
                    config.arguments = p.launchArguments
                    let result = OpenResult()
                    let open = {
                        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: p.bundlePath), configuration: config) { _, error in
                            result.finish(error)
                        }
                    }
                    if Thread.isMainThread { open() } else { DispatchQueue.main.async(execute: open) }
                    guard wait(20, until: { result.state.0 }), result.state.1 == nil else {
                        throw ResourceActionError(message: "应用已退出，重新打开未成功：\(result.state.1 ?? "超时")")
                    }
                }
            }
            let restoring = p.kind == "browser" && action == "restart"
            progress(restoring ? "\(p.name)：等待页面恢复 30 秒，再复查实际占用…" : "\(p.name)：正在复查内存…")
            Thread.sleep(forTimeInterval: restoring ? 30 : 2)
            let after = footprint(bundlePath: p.bundlePath)
            var message = "\(p.name)\(action == "restart" ? "已重启" : "已正常退出")。"
            if restoring { message += "已请求恢复普通标签，标签数量未核验。" }
            else if p.kind == "browser" { message += "保持关闭，不重新打开。" }
            if let before, let after {
                message += "应用计账内存 \(DiagnosticFormat.bytes(before)) → \(DiagnosticFormat.bytes(after))。"
            } else { message += "部分内存不可读，无法计算变化。" }
            return ResourceActionResult(ok: true, dryRun: false, status: "completed", message: message, plan: p, beforeBytes: before, afterBytes: after)
        } catch {
            return ResourceActionResult(ok: false, dryRun: dryRun, status: "not_completed",
                message: (error as? ResourceActionError)?.message ?? error.localizedDescription, plan: plan, beforeBytes: before, afterBytes: nil)
        }
    }
}
