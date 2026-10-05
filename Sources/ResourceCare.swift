import Foundation
import Darwin

enum CareService: String, Codable, CaseIterable {
    case shadowrocket, orbstack, chrome, dia
    static let basic: [CareService] = [.shadowrocket, .orbstack]
    var browser: Bool { self == .chrome || self == .dia }
    var name: String { switch self { case .shadowrocket: return "Shadowrocket"; case .orbstack: return "OrbStack"; case .chrome: return "Google Chrome"; case .dia: return "Dia" } }
    var threshold: UInt64 { self == .shadowrocket ? 512 * 1_048_576 : (self == .dia ? 3 : 2) * 1_073_741_824 }
    var adapter: String { browser ? "browser" : self == .shadowrocket ? "vpn" : "orbstack" }
    var action: String { browser ? "quit" : "restart" }
    var operation: String { browser ? "正常关闭浏览器，保持关闭" : self == .shadowrocket ? "重连隧道" : "正常重启虚拟机后台" }
}

struct CarePolicy: Codable {
    var enabled = false
    var services = CareService.basic
    var manualAllowed: Bool? = nil
    // A prior restart allowance does not silently authorize leaving browsers closed.
    var browserQuitAllowed: Bool? = nil
    var canCloseBrowsers: Bool { browserQuitAllowed == true }
    var canHandleManually: Bool { manualAllowed ?? (enabled || services.contains(where: \.browser)) }
    func permits(_ service: CareService, manual: Bool) -> Bool {
        services.contains(service) && (!service.browser || canCloseBrowsers) && (manual ? canHandleManually : enabled)
    }
}

struct CareMemoryPoint: Codable {
    let token: String
    let bytes: UInt64
    let at: Date
}

struct CareEvent: Codable {
    let at: Date
    let service: CareService
    let ok: Bool
    let message: String
    let beforeBytes: UInt64?
    let afterBytes: UInt64?
    var systemBeforeBytes: UInt64? = nil
    var systemAfterBytes: UInt64? = nil
    var pressureAfter: String? = nil
    var action: String? = nil
}

struct CareJournal: Codable {
    var points: [String: CareMemoryPoint] = [:]
    var events: [CareEvent] = []
    var checkedAt: Date?
    var summary = "尚未检查；压力持续偏高时自动给出操作建议。"
}

struct CareRunResult: Encodable {
    let ok: Bool
    let report: CareReport
    let actions: [CareEvent]
    let message: String
    var deferred: [String] = []
    var dryRun = false
    var attemptedCount: Int { actions.count }
    var status: String {
        if dryRun { return "preview" }
        if actions.isEmpty { return "no_action" }
        if performedCount == actions.count { return "completed" }
        return performedCount == 0 ? "not_completed" : "partial"
    }
    var performedCount: Int { actions.filter(\.ok).count }
    var displayMessage: String {
        guard !actions.isEmpty else { return message }
        var lines = actions.map { event -> String in
            if event.ok, let before = event.beforeBytes, let after = event.afterBytes {
                return "\(event.service.name)：\(event.action == "quit" ? "已关闭，保持关闭；" : "")\(DiagnosticFormat.bytes(before)) → \(DiagnosticFormat.bytes(after))"
            }
            return "\(event.service.name)：\(event.message)"
        }
        if let before = actions.first?.systemBeforeBytes, let after = actions.last?.systemAfterBytes {
            lines.append("系统已用 \(DiagnosticFormat.bytes(before)) → \(DiagnosticFormat.bytes(after))，压力\(actions.last?.pressureAfter ?? "未知")。")
        }
        lines.append(contentsOf: deferred)
        return lines.joined(separator: "\n")
    }
    private enum CodingKeys: String, CodingKey { case ok, report, actions, message, deferred, dryRun, attemptedCount, performedCount, status }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok); try c.encode(report, forKey: .report); try c.encode(actions, forKey: .actions)
        try c.encode(message, forKey: .message); try c.encode(deferred, forKey: .deferred); try c.encode(dryRun, forKey: .dryRun)
        try c.encode(attemptedCount, forKey: .attemptedCount); try c.encode(performedCount, forKey: .performedCount); try c.encode(status, forKey: .status)
    }
}

struct CareContext {
    let userID: UInt32
    let idleSeconds: Double?
    let foregroundBundle: String?
    var idle: Bool { idleSeconds.map { $0.isFinite && $0 >= 120 } == true }
}

struct CareSuggestion: Encodable {
    let name: String
    let state: String
    let message: String
    let service: CareService?
    let target: ProcessIdentity?
}

struct CareReport: Encodable {
    let enabled: Bool
    let checkedAt: Date
    let suggestions: [CareSuggestion]
    var ready: [CareSuggestion] { suggestions.filter { $0.state == "ready" } }
    var lines: [String] { suggestions.map { $0.message } }
    var pending: [CareSuggestion] { suggestions.filter { $0.state == "wait" || $0.state == "review" } }
    var noActionMessage: String {
        if let browser = pending.first(where: { $0.service?.browser == true }) { return "尚未关闭浏览器：" + browser.message }
        if let pending = pending.first(where: { $0.service != nil }) { return "本次暂缓：" + pending.message }
        let retained = suggestions.filter { $0.service != nil && $0.state == "keep" }
        if !retained.isEmpty { return "当前没有符合条件的处理项。" + retained.prefix(3).map(\.message).joined(separator: "；") }
        return "当前没有符合条件的处理项；工作应用和 aTrust 保留。"
    }
}

/// GUI, resident automation and CLI share decisions. Browser closing needs a separate allowance.
enum CarePlanner {
    static let successCooldown: TimeInterval = 3600
    static let failureCooldown: TimeInterval = 21600
    static func protected(_ group: ResourceGroup) -> Bool {
        group.name.localizedCaseInsensitiveContains("atrust")
            || group.processes.contains { $0.identity.executablePath.localizedCaseInsensitiveContains("atrust") }
    }
    static func service(_ group: ResourceGroup) -> CareService? {
        CareService.allCases.first { $0.name.caseInsensitiveCompare(group.name) == .orderedSame }
    }
    static func report(_ diagnosis: ResourceDiagnosis, policy: CarePolicy, journal: CareJournal,
                       context: CareContext, now: Date = Date(), batch: Bool = false) -> CareReport {
        let pressured = [.elevated, .critical].contains(diagnosis.system.memory?.pressureLevel ?? .unknown)
        var rows: [CareSuggestion] = []
        for group in diagnosis.sorted(.memory) {
            guard let target = group.processes.first?.identity, target.userID == context.userID else { continue }
            let amount = DiagnosticFormat.memory(group)
            func add(_ state: String, _ text: String, _ service: CareService? = nil) {
                rows.append(CareSuggestion(name: group.name, state: state, message: "\(group.name)：\(text)", service: service, target: target))
            }
            if protected(group) { add("ignored", "按保留规则略过。"); continue }
            if let service = service(group) {
                guard group.missingMemoryCount == 0 else { add("wait", "内存读数不完整，暂缓处理。", service); continue }
                guard (batch && service.browser) || group.footprintBytes > service.threshold else {
                    add("keep", "\(amount)，目前保留。" + (service.browser ? "未达后台关闭阈值；主动处理可关闭已允许的浏览器。" : service == .orbstack ? "运行虚拟机本身需要内存，反复重启收益有限。" : "隧道占用未达异常阈值。"), service); continue
                }
                guard diagnosis.errors.isEmpty else { add("wait", "\(amount)，诊断读数不完整，暂缓处理。", service); continue }
                guard batch || pressured else { add("wait", "\(amount)，系统压力正常，后台暂不处理；可主动按建议处理。", service); continue }
                guard policy.permits(service, manual: batch) else { add("review", "\(amount)，建议\(service.operation)；\(service.browser && !policy.canCloseBrowsers ? "关闭浏览器尚未允许。" : policy.services.contains(service) ? "当前处理未开启。" : "该项处理尚未允许。")", service); continue }
                if let recent = journal.events.last(where: { $0.service == service }),
                   service.browser, !batch, recent.action != "quit", recent.ok, let before = recent.beforeBytes, let after = recent.afterBytes,
                   Double(after) >= Double(before) * 0.9, now.timeIntervalSince(recent.at) < 86400 {
                    add("wait", "上次重启收益不足，暂停自动重试 24 小时；可能是保留的页面本身需要内存。", service); continue
                }
                if !(batch && service.browser), let recent = journal.events.last(where: { $0.service == service }),
                   (!batch || recent.ok),
                   now.timeIntervalSince(recent.at) < (recent.ok && !service.browser ? successCooldown : failureCooldown) {
                    add("wait", "\(amount)，处于\(recent.ok ? "重启后观察期" : "失败后暂停期")，避免反复操作。", service); continue
                }
                let old = journal.points[service.rawValue]
                let stable = old.map { $0.token == target.token && $0.bytes > service.threshold
                    && (60...600).contains(now.timeIntervalSince($0.at)) } == true
                guard batch || stable else { add("wait", "\(amount)，等待第二次确认持续高占用。", service); continue }
                guard batch || context.idle else { add("wait", "\(amount)，已允许处理，等你空闲 2 分钟后自动执行。", service); continue }
                guard (batch && service.browser) || context.foregroundBundle != group.bundlePath else { add("wait", "正在前台使用，稍后自动检查。", service); continue }
                guard (batch && service.browser) || (group.missingCPUCount == 0 && group.cpuPercent < 10) else { add("wait", "后台仍在忙，等负载降低后自动处理。", service); continue }
                add("ready", "\(amount)，\(batch ? "可立即" : "满足自动条件，可")\(service.operation)并复查。", service)
            } else if group.name.caseInsensitiveCompare("Sift") == .orderedSame {
                add("keep", "\(amount)，文件索引需要常驻内存，建议保留；持续增长再追查。")
            } else if group.footprintBytes >= 1_073_741_824 {
                let browser = ["Dia", "Google Chrome", "Safari", "Arc", "Microsoft Edge"].contains(group.name)
                add("review", "\(amount)，" + (browser ? "建议让闲置标签休眠、调高浏览器内存节省；保留正在使用的页面。" : "建议结束已完成的任务或关掉闲置窗口；保留当前工作。"))
            }
        }
        if rows.isEmpty { rows.append(CareSuggestion(name: "系统", state: "keep", message: "暂未发现可自动处理的异常后台应用。", service: nil, target: nil)) }
        // Put the concrete managed actions ahead of high-memory work apps and retained items.
        rows = rows.enumerated().sorted { a, b in
            func priority(_ row: CareSuggestion) -> Int {
                if row.state == "ready" { return row.service?.browser == true ? 0 : 1 }
                if row.service?.browser == true { return 2 }
                if row.service != nil { return 3 }
                if row.state == "review" { return 4 }
                return 5
            }
            let x = priority(a.element), y = priority(b.element)
            return x == y ? a.offset < b.offset : x < y
        }.map(\.element)
        return CareReport(enabled: policy.enabled, checkedAt: now, suggestions: rows)
    }
    static func observe(_ diagnosis: ResourceDiagnosis, journal: inout CareJournal, userID: UInt32, now: Date) {
        var points: [String: CareMemoryPoint] = [:]
        for group in diagnosis.groups where group.missingMemoryCount == 0 {
            guard !protected(group), let service = service(group), let target = group.processes.first?.identity,
                  target.userID == userID, group.footprintBytes > service.threshold else { continue }
            points[service.rawValue] = CareMemoryPoint(token: target.token, bytes: group.footprintBytes, at: now)
        }
        journal.points = points; journal.checkedAt = now
    }
}

/// Reuses the existing system sample. No process scan while pressure is normal, and at most once per 2 minutes otherwise.
struct CareSchedule {
    private var pressureSince: Double?
    private var lastCheck: Double?
    mutating func due(_ pressure: PressureLevel, enabled: Bool, uptime: Double) -> Bool {
        guard enabled, [.elevated, .critical].contains(pressure) else { pressureSince = nil; return false }
        if pressureSince == nil { pressureSince = uptime }
        guard uptime - pressureSince! >= 90, lastCheck.map({ uptime - $0 >= 120 }) ?? true else { return false }
        lastCheck = uptime; return true
    }
    mutating func reset() { pressureSince = nil; lastCheck = nil }
}

struct CareStore {
    static let policyChanged = Notification.Name("cyou.tianli.litegauge.care-policy-changed")
    let directory: URL
    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LiteGauge")) { self.directory = directory }
    private func read<T: Decodable>(_ name: String, default value: T) throws -> T {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return value }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    private func write<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = directory.appendingPathComponent(name)
        try encoder.encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    func policy() throws -> CarePolicy { try read("care-policy.json", default: CarePolicy()) }
    func journal() throws -> CareJournal { try read("care-history.json", default: CareJournal()) }
    func save(_ journal: CareJournal) throws { try write(journal, name: "care-history.json") }
    func setEnabled(_ enabled: Bool) throws {
        var policy = try self.policy(); policy.manualAllowed = enabled || policy.canHandleManually; policy.enabled = enabled
        try write(policy, name: "care-policy.json")
        DistributedNotificationCenter.default().postNotificationName(Self.policyChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
    func allowBrowsers() throws {
        var policy = try self.policy(); policy.enabled = true; policy.manualAllowed = true
        policy.browserQuitAllowed = true
        policy.services = CareService.allCases
        try write(policy, name: "care-policy.json")
        DistributedNotificationCenter.default().postNotificationName(Self.policyChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
    func retainBrowsers() throws {
        var policy = try self.policy(); policy.manualAllowed = policy.canHandleManually; policy.services.removeAll { $0.browser }
        policy.browserQuitAllowed = false
        try write(policy, name: "care-policy.json")
        DistributedNotificationCenter.default().postNotificationName(Self.policyChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

/// One cross-process lease for a complete action; a CLI batch and resident care cannot race each other.
final class CareLease {
    private let fd: Int32
    init(directory: URL = CareStore().directory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        fd = Darwin.open(directory.appendingPathComponent("care-action.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { let code = errno; close(fd); throw NSError(domain: NSPOSIXErrorDomain, code: Int(code)) }
    }
    deinit { flock(fd, LOCK_UN); close(fd) }
}
