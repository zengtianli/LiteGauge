import AppKit
import IOKit

enum CareRuntime {
    static func context() -> CareContext {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        var idle: Double?
        if service != 0 {
            if let number = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                idle = number.doubleValue / 1_000_000_000
            }
            IOObjectRelease(service)
        }
        var foreground: String?
        let read = { foreground = NSWorkspace.shared.frontmostApplication?.bundleURL?.path }
        if Thread.isMainThread { read() } else { DispatchQueue.main.sync(execute: read) }
        return CareContext(userID: getuid(), idleSeconds: idle, foregroundBundle: foreground)
    }

    static func preview(_ diagnosis: ResourceDiagnosis, store: CareStore = CareStore(), batch: Bool = false) throws -> CareReport {
        CarePlanner.report(diagnosis, policy: try store.policy(), journal: try store.journal(), context: context(), batch: batch)
    }

    /// Automatic checks handle one app; an explicit click handles the initial allowed plan in sequence.
    static func run(store: CareStore = CareStore(), batch: Bool, dryRun: Bool,
                    shouldContinue: () -> Bool = { true }, progress: (String) -> Void = { _ in }) throws -> CareRunResult {
        let diagnosis = ResourceDiagnostics.collect()
        if dryRun {
            let report = CarePlanner.report(diagnosis, policy: try store.policy(), journal: try store.journal(), context: context(), batch: batch)
            return CareRunResult(ok: true, report: report, actions: [], message: report.lines.joined(separator: "\n"), dryRun: true)
        }
        let lease = try CareLease(directory: store.directory)
        defer { withExtendedLifetime(lease) {} }
        let policy = try store.policy()
        var journal = try store.journal()
        let report = CarePlanner.report(diagnosis, policy: policy, journal: journal, context: context(), batch: batch)
        CarePlanner.observe(diagnosis, journal: &journal, userID: getuid(), now: report.checkedAt)
        var events: [CareEvent] = []
        var deferred: [String] = []
        let candidates = Array(report.ready.prefix(batch ? CareService.allCases.count : 1))
        for (index, initial) in candidates.enumerated() {
            guard let service = initial.service else { continue }
            let current = index == 0 ? diagnosis : ResourceDiagnostics.collect()
            let currentPolicy = try store.policy()
            let currentReport = CarePlanner.report(current, policy: currentPolicy, journal: journal, context: context(), batch: batch)
            guard currentPolicy.permits(service, manual: batch), shouldContinue(), let suggestion = currentReport.ready.first(where: { $0.service == service }),
                  let target = suggestion.target else {
                deferred.append(currentReport.suggestions.first(where: { $0.service == service })?.message ?? "\(service.name)：条件已变化，略过。")
                continue
            }
            // Name matching creates advice only; the executable's actual bundle ID must select the expected adapter.
            var event: CareEvent
            do {
                progress("正在处理 \(index + 1)/\(candidates.count)：\(service.name)…")
                let plan = try ResourceActions.prepare(pid: target.pid, token: target.token, action: service.action)
                guard plan.kind == service.adapter else { throw ResourceActionError(message: "应用身份与建议不符，本次自动操作已取消。") }
                let result = ResourceActions.perform(pid: target.pid, token: target.token, action: service.action, dryRun: false, leaseOwned: true, progress: progress)
                event = CareEvent(at: Date(), service: service, ok: result.ok, message: result.message,
                                  beforeBytes: result.beforeBytes, afterBytes: result.afterBytes)
            } catch {
                event = CareEvent(at: Date(), service: service, ok: false,
                                  message: (error as? ResourceActionError)?.message ?? error.localizedDescription,
                                  beforeBytes: nil, afterBytes: nil)
            }
            event.action = service.action
            if event.ok, let memory = MetricsSampler().sample().memory {
                event.systemBeforeBytes = current.system.memory?.usedBytes
                event.systemAfterBytes = memory.usedBytes
                event.pressureAfter = memory.pressure
            }
            events.append(event); journal.events.append(event)
            journal.events = Array(journal.events.suffix(20))
        }
        var outcome = events.isEmpty ? "本次处理 0 项。" + report.noActionMessage : events.map(\.message).joined(separator: "\n")
        if let event = events.last, let before = events.first?.systemBeforeBytes, let after = event.systemAfterBytes {
            outcome += "系统已用 \(DiagnosticFormat.bytes(before)) → \(DiagnosticFormat.bytes(after))，压力\(event.pressureAfter ?? "未知")。"
        }
        if !deferred.isEmpty { outcome += "\n" + deferred.joined(separator: "\n") }
        journal.summary = outcome
        try store.save(journal)
        return CareRunResult(ok: !events.isEmpty && events.allSatisfy(\.ok), report: report, actions: events,
                             message: outcome, deferred: deferred)
    }
}

final class AutomaticCareController {
    private let store = CareStore()
    private let queue = DispatchQueue(label: "cyou.tianli.litegauge.care", qos: .utility)
    private var schedule = CareSchedule()
    private var observer: NSObjectProtocol?
    private var generation = 0
    private var busy = false
    var isHandling: Bool { busy }
    private(set) var enabled = false
    private(set) var status = "自动处理未开启"
    var changed: ((String) -> Void)?
    var finished: (() -> Void)?

    func start() {
        reload()
        observer = DistributedNotificationCenter.default().addObserver(forName: CareStore.policyChanged, object: nil, queue: .main) { [weak self] _ in self?.reload() }
    }
    private func reload() {
        generation += 1; schedule.reset()
        do { enabled = try store.policy().enabled; status = enabled ? "自动处理已开启 · 压力持续偏高时检查" : "自动处理已暂停" }
        catch { enabled = false; status = "策略不可读，自动处理已暂停" }
        changed?(status)
    }
    func suspend() { generation += 1; schedule.reset() }
    func sample(_ snapshot: MetricsSnapshot) {
        guard !busy, schedule.due(snapshot.memory?.pressureLevel ?? .unknown, enabled: enabled,
                                   uptime: ProcessInfo.processInfo.systemUptime) else { return }
        busy = true; status = "正在自动检查并安排处理"; changed?(status)
        let ticket = generation
        queue.async { [weak self] in
            guard let self else { return }
            let result: Result<CareRunResult, Error> = Result {
                try CareRuntime.run(batch: false, dryRun: false) {
                    var valid = false
                    DispatchQueue.main.sync { valid = self.enabled && self.generation == ticket }
                    return valid
                }
            }
            DispatchQueue.main.async {
                self.busy = false
                self.finished?()
                guard self.generation == ticket else { return }
                switch result {
                case .success(let value): self.status = value.message
                case .failure(let error): self.status = "自动处理暂缓：\((error as? ResourceActionError)?.message ?? error.localizedDescription)"
                }
                self.changed?(self.status)
            }
        }
    }
    deinit { if let observer { DistributedNotificationCenter.default().removeObserver(observer) } }
}
