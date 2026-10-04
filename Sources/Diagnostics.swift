import Foundation
import Darwin

/// libproc observations, collected only for an explicit diagnosis. No task ports, shell or privileges.
struct ProcessIdentity: Encodable, Equatable {
    let pid: Int32
    let startSeconds: UInt64
    let startMicroseconds: UInt64
    let executablePath: String
    let userID: UInt32
    var token: String { "\(pid):\(startSeconds):\(startMicroseconds)" }
    static func validToken(_ token: String, pid: Int32) -> Bool {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        return parts.count == 3 && Int32(parts[0]) == pid && (UInt64(parts[1]) ?? 0) > 0
            && UInt64(parts[2]).map { $0 < 1_000_000 } == true
    }
}

struct ProcessObservation {
    let identity: ProcessIdentity
    let parentPID: Int32
    let footprintBytes: UInt64?
    let cpuNanoseconds: UInt64?
    let observedUptime: Double
}

struct ProcessUsage: Encodable {
    let identity: ProcessIdentity
    let name: String
    let footprintBytes: UInt64?
    /// 100% means one core, just like Activity Monitor's per-process CPU column.
    let cpuPercent: Double?
    var token: String { identity.token }
    private enum CodingKeys: String, CodingKey { case identity, name, footprintBytes, cpuPercent, token }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(identity, forKey: .identity); try c.encode(name, forKey: .name)
        try c.encode(footprintBytes, forKey: .footprintBytes); try c.encode(cpuPercent, forKey: .cpuPercent)
        try c.encode(token, forKey: .token)
    }
}

struct ResourceGroup: Encodable {
    let id: String
    let name: String
    let bundlePath: String?
    let processes: [ProcessUsage]
    var footprintBytes: UInt64 { processes.compactMap(\.footprintBytes).reduce(0, +) }
    var cpuPercent: Double { processes.compactMap(\.cpuPercent).reduce(0, +) }
    var missingMemoryCount: Int { processes.filter { $0.footprintBytes == nil }.count }
    var missingCPUCount: Int { processes.filter { $0.cpuPercent == nil }.count }
    private enum CodingKeys: String, CodingKey { case id, name, bundlePath, processes, footprintBytes, cpuPercent, missingMemoryCount, missingCPUCount }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
        try c.encode(bundlePath, forKey: .bundlePath); try c.encode(processes, forKey: .processes)
        try c.encode(footprintBytes, forKey: .footprintBytes); try c.encode(cpuPercent, forKey: .cpuPercent)
        try c.encode(missingMemoryCount, forKey: .missingMemoryCount); try c.encode(missingCPUCount, forKey: .missingCPUCount)
    }
}

enum DiagnosticSort: String { case memory, cpu }

enum DiagnosticFormat {
    static func bytes(_ bytes: UInt64) -> String {
        bytes >= 1_073_741_824 ? MetricFormat.gib(bytes) : String(format: "%.0f MiB", Double(bytes) / 1_048_576)
    }
    static func memory(_ group: ResourceGroup) -> String {
        guard group.missingMemoryCount < group.processes.count else { return "—" }
        return (group.missingMemoryCount > 0 ? "≥ " : "") + bytes(group.footprintBytes)
    }
    static func cpu(_ group: ResourceGroup) -> String {
        guard group.missingCPUCount < group.processes.count else { return "—" }
        return (group.missingCPUCount > 0 ? "≥ " : "") + String(format: "%.1f%%", group.cpuPercent)
    }
}

struct ResourceDiagnosis: Encodable {
    let sampledAt: Date
    let system: MetricsSnapshot
    let sampleSeconds: Double
    let groups: [ResourceGroup]
    let enumeratedProcessCount: Int
    let unreadableIdentityCount: Int
    let errors: [String]
    var ok: Bool { errors.isEmpty && !groups.isEmpty }
    let memoryAccounting = "phys_footprint 包含压缩/换出计账；按应用路径归组，不可直接相加当作物理 RAM。无法读取的进程单独计数。"
    let cpuAccounting = "区间 CPU，100% 表示一个核心；新启动或计数不可读时显示不可用。"
    private enum CodingKeys: String, CodingKey {
        case ok, sampledAt, system, sampleSeconds, groups, enumeratedProcessCount, unreadableIdentityCount, errors, memoryAccounting, cpuAccounting, advice
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok); try c.encode(sampledAt, forKey: .sampledAt)
        try c.encode(system, forKey: .system); try c.encode(sampleSeconds, forKey: .sampleSeconds)
        try c.encode(groups, forKey: .groups); try c.encode(enumeratedProcessCount, forKey: .enumeratedProcessCount)
        try c.encode(unreadableIdentityCount, forKey: .unreadableIdentityCount); try c.encode(errors, forKey: .errors)
        try c.encode(memoryAccounting, forKey: .memoryAccounting); try c.encode(cpuAccounting, forKey: .cpuAccounting)
        try c.encode(advice, forKey: .advice)
    }

    func sorted(_ sort: DiagnosticSort) -> [ResourceGroup] {
        groups.sorted {
            let a = sort == .memory ? Double($0.footprintBytes) : $0.cpuPercent
            let b = sort == .memory ? Double($1.footprintBytes) : $1.cpuPercent
            return a == b ? $0.id < $1.id : a > b
        }
    }

    var advice: [String] {
        var lines: [String] = []
        if let memory = system.memory {
            switch memory.pressureLevel {
            case .normal: lines.append("内存压力正常；占用比例高时，先看压力和交换变化，无需为了空闲比例清缓存。")
            case .elevated, .critical: lines.append("内存压力\(memory.pressure)：先查看占用靠前的应用，保存工作，再关闭不用的页面、容器或正常退出应用。")
            case .unknown: lines.append("内存压力不可读，暂时无法判断是否吃紧。")
            }
            if let swap = memory.swapUsedBytes, swap > 0 {
                lines.append("交换使用 \(MetricFormat.gib(swap))；它反映当前换出数据，不能仅凭这个数字断定应用泄漏。")
            }
        }
        if let busiest = sorted(.cpu).first, busiest.cpuPercent >= 80 {
            lines.append("\(busiest.name) 在本次采样占用 \(Int(busiest.cpuPercent.rounded()))% CPU；短时高占用需再次采样确认。")
        }
        if unreadableIdentityCount > 0 || groups.contains(where: { $0.missingMemoryCount + $0.missingCPUCount > 0 }) {
            lines.append("部分进程受系统权限限制或在采样期间退出；列表显示的是可读取范围。")
        }
        return lines
    }
}

enum NativeProcessReader {
    private static let timebase: mach_timebase_info_data_t = {
        var value = mach_timebase_info_data_t()
        mach_timebase_info(&value)
        return value
    }()
    /// rusage task CPU counters are Mach absolute-time ticks, not nanoseconds on Apple Silicon.
    static func cpuNanoseconds(_ ticks: UInt64) -> UInt64? {
        guard timebase.denom > 0 else { return nil }
        let value = Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
        guard value.isFinite, value < Double(UInt64.max) else { return nil }
        return UInt64(value)
    }
    static func identity(_ pid: Int32) -> (ProcessIdentity, Int32)? {
        guard pid > 0 else { return nil }
        var bsd = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, size) == size else { return nil }
        // libproc's 4 * MAXPATHLEN macro is not imported by Swift.
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        return (ProcessIdentity(pid: pid, startSeconds: bsd.pbi_start_tvsec, startMicroseconds: bsd.pbi_start_tvusec,
                                executablePath: String(cString: path), userID: bsd.pbi_uid), Int32(bsd.pbi_ppid))
    }

    static func observation(_ pid: Int32) -> ProcessObservation? {
        guard let (identity, parent) = identity(pid) else { return nil }
        var usage = rusage_info_v0()
        let rc = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V0, $0) }
        }
        // Recheck to avoid mixing counters from a reused pid or an exec into another executable.
        guard self.identity(pid)?.0 == identity else { return nil }
        return ProcessObservation(identity: identity, parentPID: parent,
                                  footprintBytes: rc == 0 ? usage.ri_phys_footprint : nil,
                                  cpuNanoseconds: rc == 0 ? cpuNanoseconds(usage.ri_user_time &+ usage.ri_system_time) : nil,
                                  observedUptime: ProcessInfo.processInfo.systemUptime)
    }

    static func scan() -> (observations: [ProcessObservation], count: Int, unreadable: Int, error: String?) {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return ([], 0, 0, "无法列出进程") }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 256)
        var count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        if count >= pids.count {
            pids = [Int32](repeating: 0, count: pids.count * 2)
            count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        }
        guard count > 0 else { return ([], 0, 0, "无法读取进程列表") }
        var rows: [ProcessObservation] = [], unreadable = 0
        for pid in pids.prefix(min(Int(count), pids.count)) where pid > 0 && pid != getpid() {
            if let row = observation(pid) { rows.append(row) } else { unreadable += 1 }
        }
        let error = count >= pids.count ? "进程列表在采样中增长，覆盖不完整" : nil
        return (rows, Int(count), unreadable, error)
    }
}

enum ResourceDiagnostics {
    static let warmupSeconds: Double = 1
    static func outerBundle(_ path: String) -> String? {
        let components = (path as NSString).pathComponents
        guard let end = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return NSString.path(withComponents: Array(components.prefix(end + 1)))
    }

    static func cpuPercent(current: ProcessObservation, previous: ProcessObservation?) -> Double? {
        guard let previous, previous.identity == current.identity,
              let old = previous.cpuNanoseconds, let new = current.cpuNanoseconds, new >= old,
              current.observedUptime > previous.observedUptime else { return nil }
        return Double(new - old) / 1_000_000_000 / (current.observedUptime - previous.observedUptime) * 100
    }

    static func group(current: [ProcessObservation], previous: [ProcessObservation]) -> [ResourceGroup] {
        let before = Dictionary(previous.map { ($0.identity.pid, $0) }, uniquingKeysWith: { _, last in last })
        var members: [String: [ProcessUsage]] = [:], bundles: [String: String] = [:]
        for row in current {
            let path = row.identity.executablePath
            let bundle = outerBundle(path)
            // UID is part of the key; the same app belonging to another login is not ours to quit.
            let key = "\(row.identity.userID):\(bundle ?? path)"
            if let bundle { bundles[key] = bundle }
            members[key, default: []].append(ProcessUsage(identity: row.identity, name: (path as NSString).lastPathComponent,
                footprintBytes: row.footprintBytes, cpuPercent: cpuPercent(current: row, previous: before[row.identity.pid])))
        }
        return members.map { key, rows in
            let bundle = bundles[key]
            let name = bundle.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension } ?? rows[0].name
            return ResourceGroup(id: key, name: name, bundlePath: bundle,
                                 processes: rows.sorted { ($0.footprintBytes ?? 0) > ($1.footprintBytes ?? 0) })
        }
    }

    static func collect(warmup: Double = warmupSeconds) -> ResourceDiagnosis {
        let start = ProcessInfo.processInfo.systemUptime
        let sampler = MetricsSampler()
        _ = sampler.sample()
        let first = NativeProcessReader.scan()
        Thread.sleep(forTimeInterval: max(0.1, min(5, warmup)))
        let last = NativeProcessReader.scan()
        let system = sampler.sample()
        let errors = [first.error, last.error].compactMap { $0 } + system.errors
        return ResourceDiagnosis(sampledAt: Date(), system: system, sampleSeconds: ProcessInfo.processInfo.systemUptime - start,
            groups: group(current: last.observations, previous: first.observations), enumeratedProcessCount: last.count,
            unreadableIdentityCount: last.unreadable, errors: errors)
    }
}
