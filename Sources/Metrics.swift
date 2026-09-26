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

struct MemoryReading: Codable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64?
    let pressure: String
    var percent: Double { Double(usedBytes) / Double(totalBytes) * 100 }
}

struct DiskReading: Codable {
    let volume: String
    let totalBytes: UInt64
    let availableBytes: UInt64
    let sampledAt: Date
    var usedPercent: Double { 100 * (1 - Double(availableBytes) / Double(totalBytes)) }
}

struct MetricsSnapshot: Codable {
    let sampledAt: Date
    let cpuPercent: Double?
    let memory: MemoryReading?
    let disk: DiskReading?
    let errors: [String]
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
    static let diskInterval: TimeInterval = 60

    deinit { mach_port_deallocate(mach_task_self_, host) }

    func resetCPU() { previous = nil }

    func sample(forceDisk: Bool = false) -> MetricsSnapshot {
        var errors: [String] = []
        let now = Date()
        let ticks = readCPU()
        let cpu = ticks.flatMap { t in previous.flatMap { t.usage(since: $0) } }
        previous = ticks
        if ticks == nil { errors.append("无法读取 CPU") }
        let memory = readMemory()
        if memory == nil { errors.append("无法读取内存") }
        let uptime = ProcessInfo.processInfo.systemUptime
        if forceDisk || uptime - lastDiskRead >= Self.diskInterval {
            cachedDisk = readDisk(now: now)
            diskError = cachedDisk == nil ? "无法读取启动磁盘" : nil
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
        let label: String
        switch pressureOK ? pressure : 0 {
        case 1: label = "正常"
        case 2: label = "偏高"
        case 4: label = "紧张"
        default: label = "未知"
        }
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapOK = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
        return MemoryReading(totalBytes: total, usedBytes: used,
            compressedBytes: UInt64(stats.compressor_page_count) * pageSize,
            swapUsedBytes: swapOK ? swap.xsu_used : nil, pressure: label)
    }

    private func readDisk(now: Date) -> DiskReading? {
        // The writable data volume belongs to the startup APFS container; count it once.
        var info = statfs()
        guard statfs("/System/Volumes/Data", &info) == 0, info.f_blocks > 0 else { return nil }
        let block = UInt64(info.f_bsize)
        return DiskReading(volume: "启动磁盘", totalBytes: info.f_blocks * block,
            availableBytes: min(info.f_bavail, info.f_blocks) * block, sampledAt: now)
    }
}

enum MetricFormat {
    static func percent(_ value: Double?) -> String { value.map { String(format: "%.0f%%", $0) } ?? "—" }
    static func gb(_ bytes: UInt64) -> String { String(format: "%.1f GB", Double(bytes) / 1_000_000_000) }
    static func gib(_ bytes: UInt64) -> String { String(format: "%.1f GiB", Double(bytes) / 1_073_741_824) }
    static func status(_ snapshot: MetricsSnapshot) -> String {
        "CPU \(percent(snapshot.cpuPercent))   MEM \(percent(snapshot.memory?.percent))   SSD \(percent(snapshot.disk?.usedPercent))"
    }
}
