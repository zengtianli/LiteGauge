import Foundation
import Darwin

enum CareService: String, Codable, CaseIterable {
    case shadowrocket, orbstack, chrome, dia
    static let basic: [CareService] = [.shadowrocket, .orbstack]
    var browser: Bool { self == .chrome || self == .dia }
    var name: String { switch self { case .shadowrocket: return "Shadowrocket"; case .orbstack: return "OrbStack"; case .chrome: return "Google Chrome"; case .dia: return "Dia" } }
    var threshold: UInt64 { self == .shadowrocket ? 512 * 1_048_576 : (self == .dia ? 3 : 2) * 1_073_741_824 }
    var adapter: String { browser ? "browser" : self == .shadowrocket ? "vpn" : "orbstack" }
    var operation: String { browser ? "重启浏览器并恢复普通标签" : self == .shadowrocket ? "重连隧道" : "正常重启虚拟机后台" }
}

struct CarePolicy: Codable {
    var enabled = false
    var services = CareService.basic
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
}

struct CareJournal: Codable {
    var points: [String: CareMemoryPoint] = [:]
    var events: [CareEvent] = []
    var checkedAt: Date?
    var summary = "尚未检查；压力持续偏高时自动给出操作建议。"
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
        if let browser = pending.first(where: { $0.service?.browser == true }) { return "尚未恢复主要占用：" + browser.message }
        if let pending = pending.first { return "本次暂缓：" + pending.message }
        return "本次无需处理已允许的后台应用；当前占用保留。"
    }
}

/// Decisions are shared by the GUI, resident automation and CLI. Browser recovery needs its own opt-in.
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
                guard group.footprintBytes > service.threshold else {
                    add("keep", "\(amount)，目前保留。" + (service.browser ? "未达浏览器恢复阈值。" : service == .orbstack ? "运行虚拟机本身需要内存，反复重启收益有限。" : "隧道占用未达异常阈值。"), service); continue
                }
                guard pressured, diagnosis.errors.isEmpty else { add("wait", "\(amount)，等待持续内存压力和完整读数。", service); continue }
                guard policy.enabled, policy.services.contains(service) else { add("review", "\(amount)，建议\(service.operation)；\(service.browser ? "浏览器恢复重启尚未允许，总占用不会因此自动降低。" : "自动处理尚未允许。")", service); continue }
                if let recent = journal.events.last(where: { $0.service == service }),
                   service.browser, recent.ok, let before = recent.beforeBytes, let after = recent.afterBytes,
                   Double(after) >= Double(before) * 0.9, now.timeIntervalSince(recent.at) < 86400 {
                    add("wait", "上次重启收益不足，暂停自动重试 24 小时；可能是保留的页面本身需要内存。", service); continue
                }
                if let recent = journal.events.last(where: { $0.service == service }),
                   now.timeIntervalSince(recent.at) < (recent.ok && !service.browser ? successCooldown : failureCooldown) {
                    add("wait", "\(amount)，处于\(recent.ok ? "重启后观察期" : "失败后暂停期")，避免反复操作。", service); continue
                }
                let old = journal.points[service.rawValue]
                let stable = old.map { $0.token == target.token && $0.bytes > service.threshold
                    && (60...600).contains(now.timeIntervalSince($0.at)) } == true
                guard batch || stable else { add("wait", "\(amount)，等待第二次确认持续高占用。", service); continue }
                guard batch || context.idle else { add("wait", "\(amount)，已允许处理，等你空闲 2 分钟后自动执行。", service); continue }
                guard context.foregroundBundle != group.bundlePath else { add("wait", "正在前台使用，稍后自动检查。", service); continue }
                guard group.missingCPUCount == 0, group.cpuPercent < 10 else { add("wait", "后台仍在忙，等负载降低后自动处理。", service); continue }
                add("ready", "\(amount)，已安排\(service.operation)并复查。", service)
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
        var policy = try self.policy(); policy.enabled = enabled
        try write(policy, name: "care-policy.json")
        DistributedNotificationCenter.default().postNotificationName(Self.policyChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
    func allowBrowsers() throws {
        var policy = try self.policy(); policy.enabled = true
        policy.services = CareService.allCases
        try write(policy, name: "care-policy.json")
        DistributedNotificationCenter.default().postNotificationName(Self.policyChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
    func retainBrowsers() throws {
        var policy = try self.policy(); policy.services.removeAll { $0.browser }
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
