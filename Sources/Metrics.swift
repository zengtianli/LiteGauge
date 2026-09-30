import Foundation
import Darwin

struct SamplingState {
    private var reasons = Set<String>()
    var isRunning: Bool { reasons.isEmpty }
    mutating func setPaused(_ paused: Bool, reason: String) {
        if paused { reasons.insert(reason) } else { reasons.remove(reason) }
    }
}

struct CPUTicks: Equatable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func usage(since previous: CPUTicks) -> Double? {
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system) + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        guard total > 0 else { return nil }
        return min(100, Double(busy) / Double(total) * 100)
    }
}

enum AppIdentity {
    static let bundleID = "cyou.tianli.litegauge"
}

/// Kernel memory pressure (kern.memorystatus_vm_pressure_level). `rawValue` is the stable machine value.
enum PressureLevel: String, CaseIterable {
    case normal, elevated, critical, unknown

    init(kernelLevel: Int32?) {
        switch kernelLevel {
        case 1: self = .normal
        case 2: self = .elevated
        case 4: self = .critical
        default: self = .unknown
        }
    }

    init(label: String) { self = Self.allCases.first { $0.label == label } ?? .unknown }

    var label: String {
        switch self {
        case .normal: return "正常"
        case .elevated: return "偏高"
        case .critical: return "紧张"
        case .unknown: return "未知"
        }
    }
}

/// How the panel colours a reading. The GUI draws from it and the CLI reports it, so both judge alike.
enum MetricLevel: String {
    case normal, warning, critical
}

enum MetricThresholds {
    /// The panel's disk bar turns orange above this used percentage.
    static let diskWarnPercent: Double = 90

    static func memoryLevel(_ pressure: PressureLevel) -> MetricLevel {
        switch pressure {
        case .critical: return .critical
        case .elevated: return .warning
        case .normal, .unknown: return .normal
        }
    }

    static func diskLevel(usedPercent: Double) -> MetricLevel { usedPercent > diskWarnPercent ? .warning : .normal }
}

/// Collection failures. `label` is what the panel and text output show; `rawValue` is the stable code.
enum MetricError: String, CaseIterable {
    case cpu = "cpu_unavailable"
    case memory = "memory_unavailable"
    case disk = "disk_unavailable"

    init?(label: String) {
        guard let match = Self.allCases.first(where: { $0.label == label }) else { return nil }
        self = match
    }

    var label: String {
        switch self {
        case .cpu: return "无法读取 CPU"
        case .memory: return "无法读取内存"
        case .disk: return "无法读取启动磁盘"
        }
    }
}

struct MemoryReading: Encodable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64?
    let pressureLevel: PressureLevel

    init(totalBytes: UInt64, usedBytes: UInt64, compressedBytes: UInt64, swapUsedBytes: UInt64?, pressureLevel: PressureLevel) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.compressedBytes = compressedBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureLevel = pressureLevel
    }

    /// Display-label form, kept for the media fixture (scripts/capture/main.swift).
    init(totalBytes: UInt64, usedBytes: UInt64, compressedBytes: UInt64, swapUsedBytes: UInt64?, pressure: String) {
        self.init(totalBytes: totalBytes, usedBytes: usedBytes, compressedBytes: compressedBytes,
                  swapUsedBytes: swapUsedBytes, pressureLevel: PressureLevel(label: pressure))
    }

    var pressure: String { pressureLevel.label }
    var percent: Double { Double(usedBytes) / Double(totalBytes) * 100 }
    var level: MetricLevel { MetricThresholds.memoryLevel(pressureLevel) }

    private enum Keys: String, CodingKey {
        case totalBytes, usedBytes, compressedBytes, swapUsedBytes, pressure, pressureLevel, percent, level
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(totalBytes, forKey: .totalBytes)
        try c.encode(usedBytes, forKey: .usedBytes)
        try c.encode(compressedBytes, forKey: .compressedBytes)
        try c.encode(swapUsedBytes, forKey: .swapUsedBytes)
        try c.encode(pressure, forKey: .pressure)
        try c.encode(pressureLevel.rawValue, forKey: .pressureLevel)
        try c.encode(percent, forKey: .percent)
        try c.encode(level.rawValue, forKey: .level)
    }
}

struct DiskReading: Encodable {
    /// The writable data volume of the startup APFS container.
    static let mountPoint = "/System/Volumes/Data"
    let volume: String
    let totalBytes: UInt64
    let availableBytes: UInt64
    let sampledAt: Date
    var usedPercent: Double { 100 * (1 - Double(availableBytes) / Double(totalBytes)) }
    var level: MetricLevel { MetricThresholds.diskLevel(usedPercent: usedPercent) }

    private enum Keys: String, CodingKey {
        case volume, mountPoint, totalBytes, availableBytes, usedPercent, level, warnAbovePercent, sampledAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(volume, forKey: .volume)
        try c.encode(Self.mountPoint, forKey: .mountPoint)
        try c.encode(totalBytes, forKey: .totalBytes)
        try c.encode(availableBytes, forKey: .availableBytes)
        try c.encode(usedPercent, forKey: .usedPercent)
        try c.encode(level.rawValue, forKey: .level)
        try c.encode(MetricThresholds.diskWarnPercent, forKey: .warnAbovePercent)
        try c.encode(sampledAt, forKey: .sampledAt)
    }
}

struct MetricsSnapshot: Encodable {
    let sampledAt: Date
    let cpuPercent: Double?
    let memory: MemoryReading?
    let disk: DiskReading?
    let errors: [String]

    var ok: Bool { errors.isEmpty }

    private enum Keys: String, CodingKey { case ok, sampledAt, cpuPercent, memory, disk, errors, errorCodes }

    // Missing readings are written as null, so every key is always present.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(ok, forKey: .ok)
        try c.encode(sampledAt, forKey: .sampledAt)
        try c.encode(cpuPercent, forKey: .cpuPercent)
        try c.encode(memory, forKey: .memory)
        try c.encode(disk, forKey: .disk)
        try c.encode(errors, forKey: .errors)
        try c.encode(errors.map { MetricError(label: $0)?.rawValue ?? "unknown" }, forKey: .errorCodes)
    }
}

enum MetricMath {
    // Reclaimable file cache and purgeable pages do not mean memory pressure.
    static func usedMemory(active: UInt64, inactive: UInt64, speculative: UInt64,
                           wired: UInt64, compressed: UInt64, purgeable: UInt64,
                           external: UInt64, pageSize: UInt64, total: UInt64) -> UInt64 {
        let occupied = active + inactive + speculative + wired + compressed
        let reclaimable = purgeable + external
        return min(total, (occupied > reclaimable ? occupied - reclaimable : 0) * pageSize)
    }
}

final class MetricsSampler {
    private let host = mach_host_self()
    private var previous: CPUTicks?
    private var cachedDisk: DiskReading?
    private var lastDiskRead: TimeInterval = -.infinity
    private var diskError: String?
    /// CPU/memory cadence of the running App (and `watch`'s default); disk capacity is cached for `diskInterval`.
    static let sampleInterval: TimeInterval = 2
    static let diskInterval: TimeInterval = 60

    deinit { mach_port_deallocate(mach_task_self_, host) }

    func resetCPU() { previous = nil }

    func sample(forceDisk: Bool = false) -> MetricsSnapshot {
        var errors: [String] = []
        let now = Date()
        let ticks = readCPU()
        let cpu = ticks.flatMap { t in previous.flatMap { t.usage(since: $0) } }
        previous = ticks
        if ticks == nil { errors.append(MetricError.cpu.label) }
        let memory = readMemory()
        if memory == nil { errors.append(MetricError.memory.label) }
        let uptime = ProcessInfo.processInfo.systemUptime
        if forceDisk || uptime - lastDiskRead >= Self.diskInterval {
            cachedDisk = readDisk(now: now)
            diskError = cachedDisk == nil ? MetricError.disk.label : nil
            lastDiskRead = uptime
        }
        if let diskError { errors.append(diskError) }
        return MetricsSnapshot(sampledAt: now, cpuPercent: cpu, memory: memory, disk: cachedDisk, errors: errors)
    }

    private func readCPU() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    private func readMemory() -> MemoryReading? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(vm_page_size)
        let used = MetricMath.usedMemory(active: UInt64(stats.active_count), inactive: UInt64(stats.inactive_count),
            speculative: UInt64(stats.speculative_count), wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count), purgeable: UInt64(stats.purgeable_count),
            external: UInt64(stats.external_page_count), pageSize: pageSize, total: total)
        var pressure: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let pressureOK = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) == 0
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapOK = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
        return MemoryReading(totalBytes: total, usedBytes: used,
            compressedBytes: UInt64(stats.compressor_page_count) * pageSize,
            swapUsedBytes: swapOK ? swap.xsu_used : nil, pressureLevel: PressureLevel(kernelLevel: pressureOK ? pressure : nil))
    }

    private func readDisk(now: Date) -> DiskReading? {
        // The writable data volume belongs to the startup APFS container; count it once.
        var info = statfs()
        guard statfs(DiskReading.mountPoint, &info) == 0, info.f_blocks > 0 else { return nil }
        let block = UInt64(info.f_bsize)
        return DiskReading(volume: "启动磁盘", totalBytes: info.f_blocks * block,
            availableBytes: min(info.f_bavail, info.f_blocks) * block, sampledAt: now)
    }
}

enum MetricFormat {
    static func percent(_ value: Double?) -> String { value.map { String(format: "%.0f%%", $0) } ?? "—" }
    static func gb(_ bytes: UInt64) -> String { String(format: "%.1f GB", Double(bytes) / 1_000_000_000) }
    static func gib(_ bytes: UInt64) -> String { String(format: "%.1f GiB", Double(bytes) / 1_073_741_824) }
    /// Panel footer when there is no error; mirrors the sampler's cadence constants.
    static let cadence = "每 \(Int(MetricsSampler.sampleInterval)) 秒更新 · 磁盘每 \(Int(MetricsSampler.diskInterval)) 秒更新"
    static func status(_ snapshot: MetricsSnapshot) -> String {
        "CPU \(percent(snapshot.cpuPercent))   MEM \(percent(snapshot.memory?.percent))   SSD \(percent(snapshot.disk?.usedPercent))"
    }
}
