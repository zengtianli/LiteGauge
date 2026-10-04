import Foundation

var checks = 0
func check(_ ok: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !ok() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
let initial = CPUTicks(user: 10, system: 10, idle: 80, nice: 0)
var state = SamplingState()
state.setPaused(true, reason: "lock")
state.setPaused(true, reason: "screen")
state.setPaused(false, reason: "screen")
check(!state.isRunning, "screen wake must not resume while locked")
state.setPaused(false, reason: "lock")
check(state.isRunning, "resume once all pause reasons clear")
check(CPUTicks(user: 20, system: 20, idle: 160, nice: 0).usage(since: initial) == 20, "CPU uses interval delta")
check(initial.usage(since: initial) == nil, "zero delta is unavailable, not NaN")
check(CPUTicks(user: 2, system: 0, idle: 2, nice: 0).usage(since: CPUTicks(user: UInt32.max, system: 0, idle: UInt32.max, nice: 0)) == 50, "CPU tick wraparound")
check(MetricMath.usedMemory(active: 20, inactive: 20, speculative: 5, wired: 10, compressed: 5, purgeable: 5, external: 20, pageSize: 4, total: 400) == 140, "reclaimable cache excluded")
check(MetricMath.usedMemory(active: 1, inactive: 0, speculative: 0, wired: 0, compressed: 0, purgeable: 10, external: 10, pageSize: 4, total: 400) == 0, "memory counters cannot underflow")
let sampler = MetricsSampler()
let first = sampler.sample()
check(first.cpuPercent == nil, "first CPU sample has no baseline")
Thread.sleep(forTimeInterval: 1)
let second = sampler.sample()
check(second.cpuPercent != nil && (0...100).contains(second.cpuPercent!), "live CPU valid")
check(second.memory != nil && second.memory!.usedBytes <= second.memory!.totalBytes, "live memory valid")
check(second.disk != nil && second.disk!.availableBytes <= second.disk!.totalBytes, "live APFS capacity valid")
check(first.disk?.sampledAt == second.disk?.sampledAt, "disk capacity cached between ticks")
let refreshed = sampler.sample(forceDisk: true)
check(refreshed.disk!.sampledAt > second.disk!.sampledAt, "manual refresh bypasses disk cache")
sampler.resetCPU()
check(sampler.sample().cpuPercent == nil, "wake resets CPU baseline")

// Shared classification: the panel colours and the CLI JSON read the same enums and thresholds.
check([Int32(1), 2, 4, 0, 3].map { PressureLevel(kernelLevel: $0) } == [.normal, .elevated, .critical, .unknown, .unknown], "kernel pressure levels")
check(PressureLevel(kernelLevel: nil) == .unknown, "unreadable pressure is unknown")
check(PressureLevel.allCases.allSatisfy { PressureLevel(label: $0.label) == $0 }, "pressure label round-trip")
check(PressureLevel.allCases.map(MetricThresholds.memoryLevel) == [.normal, .warning, .critical, .normal], "memory colour classes")
check(MetricThresholds.diskLevel(usedPercent: 90) == .normal && MetricThresholds.diskLevel(usedPercent: 90.01) == .warning, "disk warns above 90%")
check(MetricError.allCases.allSatisfy { MetricError(label: $0.label) == $0 } && MetricError(label: "x") == nil, "error code round-trip")
let fixtureMemory = MemoryReading(totalBytes: 400, usedBytes: 100, compressedBytes: 0, swapUsedBytes: nil, pressure: "偏高")
check(fixtureMemory.pressureLevel == .elevated && fixtureMemory.level == .warning && fixtureMemory.percent == 25, "display-label initializer")
let fixtureDisk = DiskReading(volume: "启动磁盘", totalBytes: 1000, availableBytes: 50, sampledAt: Date(timeIntervalSince1970: 0))
check(fixtureDisk.level == .warning && abs(fixtureDisk.usedPercent - 95) < 1e-9, "disk usage and level")
func object(_ json: String) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
}
let failedSnapshot = MetricsSnapshot(sampledAt: Date(timeIntervalSince1970: 0), cpuPercent: nil, memory: fixtureMemory,
                                     disk: fixtureDisk, errors: [MetricError.cpu.label])
let encoded = object(try CLIOutput.json(failedSnapshot, pretty: false))
let memJSON = encoded["memory"] as? [String: Any] ?? [:], diskJSON = encoded["disk"] as? [String: Any] ?? [:]
check(encoded["ok"] as? Bool == false && encoded["cpuPercent"] is NSNull && encoded["errorCodes"] as? [String] == ["cpu_unavailable"],
      "snapshot JSON: ok, null CPU, error codes")
check(memJSON["pressure"] as? String == "偏高" && memJSON["pressureLevel"] as? String == "elevated" && memJSON["level"] as? String == "warning"
      && memJSON["percent"] as? Double == 25 && memJSON["swapUsedBytes"] is NSNull, "memory JSON keeps label, adds machine values")
check(diskJSON["volume"] as? String == "启动磁盘" && diskJSON["level"] as? String == "warning" && diskJSON["warnAbovePercent"] as? Double == 90
      && diskJSON["mountPoint"] as? String == "/System/Volumes/Data" && diskJSON["usedPercent"] != nil, "disk JSON adds used%, level, threshold")
let emptySnapshot = object(try CLIOutput.json(MetricsSnapshot(sampledAt: Date(), cpuPercent: 1, memory: nil, disk: nil, errors: []), pretty: false))
check(emptySnapshot["memory"] is NSNull && emptySnapshot["disk"] is NSNull && emptySnapshot["ok"] as? Bool == true, "missing readings are null, not absent")
check(CLIOutput.statusLines(failedSnapshot)[2].hasSuffix("已用超过 90%"), "text status flags the disk warning")

// Command-line parsing: help always exits 0, the short name never starts the GUI, bad input is a usage error.
func parsed(_ args: [String], as name: String = "litegauge") -> CLICommand? { try? CLI.parse(args, invokedAs: name).get() }
func rejected(_ args: [String]) -> Bool { parsed(args) == nil }
check(parsed([]) == .usage && parsed([], as: "/usr/local/bin/litegauge") == .usage, "short name with no arguments prints usage")
check(parsed([], as: "/Applications/LiteGauge.app/Contents/MacOS/LiteGauge") == .gui(benchmark: nil), "bundle executable starts the App")
check([["--help"], ["-h"], ["help"], ["status", "--help"], ["watch", "-h"], ["app", "quit", "--help"], ["--version", "--help"],
       ["watch", "--count", "1", "--help"], ["app", "quit", "--yes", "-h"]]
      .allSatisfy { parsed($0) == .help }, "help spellings")
// The dev flags listed in --help must not run their action (start a GUI instance, write a file) when asked for help.
check([["--benchmark", "--help"], ["--snapshot", "-h"], ["--ui-self-test", "--help"], ["--background", "--help"], ["--bogus", "-h"]]
      .allSatisfy { parsed($0) == .help }, "help after a dev flag shows help instead of running it")
check(parsed(["status"]) == .status(json: false) && parsed(["status", "--json"]) == .status(json: true), "status")
check(parsed(["--version", "--json"]) == .version(json: true), "version json")
check(parsed(["watch"]) == .watch(WatchOptions()) && WatchOptions().interval == MetricsSampler.sampleInterval, "watch defaults to the App cadence")
check(parsed(["watch", "--interval", "5", "--count=3", "--json"]) == .watch(WatchOptions(interval: 5, count: 3, json: true)), "watch options")
check(parsed(["app", "status", "--json"]) == .appStatus(json: true), "app status")
check(parsed(["app", "quit", "--dry-run"]) == .appQuit(json: false, dryRun: true, pid: nil)
      && parsed(["app", "quit", "--yes", "--json"]) == .appQuit(json: true, dryRun: false, pid: nil)
      && parsed(["app", "quit", "--yes", "--pid", "4242"]) == .appQuit(json: false, dryRun: false, pid: 4242)
      && parsed(["app", "quit", "--dry-run", "--pid=7"]) == .appQuit(json: false, dryRun: true, pid: 7), "app quit")
check(parsed(["--background"]) == .gui(benchmark: nil) && parsed(["--benchmark", "f.json"]) == .gui(benchmark: "f.json"), "dev launch flags")
check(parsed(["--ui-self-test"]) == .uiSelfTest(dir: nil) && parsed(["--snapshot", "a.png"]) == .snapshot(path: "a.png"), "dev render flags")
check([["--json"], ["status", "--json", "extra"], ["status", "--json", "--json"], ["watch", "--interval", "0.5"],
       ["watch", "--interval"], ["watch", "--count", "0"], ["watch", "--interval", "nan"], ["app"], ["app", "start"],
       ["app", "quit"], ["app", "quit", "--yes", "--dry-run"], ["app", "quit", "--pid", "1"], ["app", "quit", "--yes", "--pid", "0"],
       ["app", "quit", "--yes", "--pid", "-3"], ["app", "quit", "--yes", "--pid", "abc"], ["app", "quit", "--yes", "--pid"],
       ["--snapshot"], ["--background", "x"], ["--bogus"]]
      .allSatisfy(rejected), "usage errors")

// The version constant (help text, fallback outside a bundle) must match the Info.plist the bundle ships with.
let plist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Info.plist")
let plistVersion = (NSDictionary(contentsOf: plist)?["CFBundleShortVersionString"] as? String)
check(plistVersion == version, "CLI version constant \(version) matches Info.plist \(plistVersion ?? "missing")")

// app quit --yes: SIGTERM, then wait. Exercised on real child processes (never on a LiteGauge instance).
func spawn(_ path: String, _ args: [String], blockTERM: Bool = false) -> pid_t {
    var pid: pid_t = 0
    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    if blockTERM {   // a blocked TERM stays pending, like an App that does not exit in time
        var mask = sigset_t()
        sigemptyset(&mask)
        sigaddset(&mask, SIGTERM)
        posix_spawnattr_setsigmask(&attr, &mask)
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSIGMASK))
    }
    let argv = ([path] + args).map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }
    let rc = posix_spawn(&pid, path, nil, &attr, argv, environ)
    precondition(rc == 0, "posix_spawn \(path): \(rc)")
    return pid
}
let quitStart = Date()
let sleeper = spawn("/bin/sleep", ["30"])
let quitResult = CLIProcess.terminate([sleeper])
check(quitResult.stillRunning.isEmpty && quitResult.errors.isEmpty && Date().timeIntervalSince(quitStart) < 3
      && !CLIProcess.isAlive(sleeper), "terminate ends a process that honours SIGTERM")
let stubborn = spawn("/bin/sleep", ["30"], blockTERM: true)
let stuck = CLIProcess.terminate([stubborn], timeout: 0.3)
check(stuck.stillRunning == [stubborn] && stuck.errors.isEmpty, "terminate reports a process still running at the deadline")
kill(stubborn, SIGKILL)
_ = waitpid(stubborn, nil, 0)
let gone = CLIProcess.terminate([stubborn], timeout: 0.3)
check(gone.stillRunning.isEmpty && gone.errors.isEmpty, "terminate treats an already-gone pid as done (idempotent)")

// watch streams one compact JSON object per line from one sampler; disk stays cached between records.
var lines: [String] = []
let stopNever = DispatchSemaphore(value: 0)
// Same 1-second CPU warm-up as the CLI: kernel tick counters can stay flat over much shorter windows.
let watchCode = try CLISampling.watch(WatchOptions(interval: 1, count: 2, json: true), stop: stopNever) { lines.append($0) }
let records = lines.map(object)
check(watchCode == 0 && lines.count == 2 && lines.allSatisfy { $0.hasSuffix("\n") && $0.dropLast().contains("\n") == false },
      "watch --count 2 --json writes two NDJSON lines")
let recordDisks = records.map { ($0["disk"] as? [String: Any])?["sampledAt"] as? String }
check(records.allSatisfy { $0["cpuPercent"] is Double }, "watch records all have a CPU reading: \(lines)")
check(recordDisks.count == 2 && recordDisks[0] != nil && recordDisks[0] == recordDisks[1], "watch keeps the disk reading cached between records: \(recordDisks)")
var stopLines = 0
let stopSoon = DispatchSemaphore(value: 0)
_ = try CLISampling.watch(WatchOptions(interval: 30, count: nil, json: false), stop: stopSoon, warmup: 0.3) { _ in
    stopLines += 1
    stopSoon.signal()
}
check(stopLines == 1, "a stop signal ends an unbounded watch after the current line")
// On-demand process diagnosis: stable identities, interval CPU and app aggregation.
func observation(_ pid: Int32, _ path: String, start: UInt64 = 1, uid: UInt32 = 501,
                 memory: UInt64? = 10, cpu: UInt64? = 0, at: Double = 1) -> ProcessObservation {
    ProcessObservation(identity: ProcessIdentity(pid: pid, startSeconds: start, startMicroseconds: 0, executablePath: path, userID: uid),
                       parentPID: 1, footprintBytes: memory, cpuNanoseconds: cpu, observedUptime: at)
}
let appPath = "/Applications/Example.app/Contents/MacOS/Example"
let helperPath = "/Applications/Example.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper"
let oldProcess = observation(100, appPath, cpu: 1_000_000_000)
let currentProcess = observation(100, appPath, cpu: 2_000_000_000, at: 3)
check(ResourceDiagnostics.cpuPercent(current: currentProcess, previous: oldProcess) == 50, "interval CPU uses individual monotonic timestamps")
check(ResourceDiagnostics.cpuPercent(current: observation(100, appPath, start: 2, cpu: 4_000_000_000, at: 3), previous: oldProcess) == nil,
      "a reused PID never inherits the old CPU baseline")
check(ResourceDiagnostics.cpuPercent(current: observation(100, helperPath, cpu: 4_000_000_000, at: 3), previous: oldProcess) == nil,
      "an exec into another path resets CPU")
check(ResourceDiagnostics.cpuPercent(current: observation(100, appPath, cpu: 0, at: 3), previous: oldProcess) == nil,
      "decreasing CPU counters are unavailable, not a negative usage")
let appGroups = ResourceDiagnostics.group(current: [currentProcess, observation(101, helperPath, memory: 20),
    observation(102, appPath, uid: 502, memory: 30), observation(103, "/usr/local/bin/job", memory: nil, cpu: nil)], previous: [oldProcess])
let ownGroup = appGroups.first { $0.id.hasPrefix("501:/Applications/") }!
check(appGroups.count == 3 && ownGroup.processes.count == 2 && ownGroup.footprintBytes == 30 && ownGroup.cpuPercent == 50,
      "nested helpers aggregate under the outer app; another user's app and standalone jobs remain separate")
check(ownGroup.missingCPUCount == 1 && DiagnosticFormat.cpu(ownGroup).hasPrefix("≥"), "partial CPU coverage is explicit")
let unavailableGroup = appGroups.first { $0.bundlePath == nil }!
check(DiagnosticFormat.memory(unavailableGroup) == "—" && DiagnosticFormat.cpu(unavailableGroup) == "—", "unreadable processes display unavailable")
check(ResourceDiagnostics.outerBundle(helperPath) == "/Applications/Example.app" && ResourceDiagnostics.outerBundle("/usr/bin/job") == nil,
      "bundle grouping does not confuse executable names with app paths")
check(ProcessIdentity.validToken("100:1:999999", pid: 100) && !ProcessIdentity.validToken("100:1:1000000", pid: 100)
      && !ProcessIdentity.validToken("100::0", pid: 100) && !ProcessIdentity.validToken("101:1:0", pid: 100), "identity tokens reject malformed or mismatched targets")
check(parsed(["diagnose"]) == .diagnose(json: false, sort: .memory, limit: 10)
      && parsed(["diagnose", "--sort=cpu", "--limit", "20", "--json"]) == .diagnose(json: true, sort: .cpu, limit: 20), "diagnose ranking and limit")
check(parsed(["process", "restart", "--pid", "100", "--token", "100:1:0", "--dry-run"])
      == .processAction(json: false, dryRun: true, action: "restart", pid: 100, token: "100:1:0"), "restart is explicit and supports preview")
check([["process", "restart", "--pid", "100", "--token", "100:1:0"],
       ["process", "restart", "--pid", "100", "--token", "101:1:0", "--yes"],
       ["process", "restart", "--pid", "100", "--token", "100:1:0", "--yes", "--dry-run"],
       ["diagnose", "--limit", "0"], ["diagnose", "--limit", "51"], ["diagnose", "--sort", "random"]].allSatisfy(rejected),
      "actions require confirmation and a bound identity; invalid ranks are rejected")
check(parsed(["process", "restart", "--yes", "--help"]) == .help, "help never performs an action")
let selfObservation = NativeProcessReader.observation(getpid())
check(selfObservation?.identity.pid == getpid() && (selfObservation?.footprintBytes ?? 0) > 0 && selfObservation?.cpuNanoseconds != nil,
      "native libproc reports this real process's footprint and CPU")
// Compare a real CPU burst with getrusage's microsecond clock. This catches Mach-tick/nanosecond confusion.
var burstBefore = rusage(), burstAfter = rusage()
getrusage(RUSAGE_SELF, &burstBefore)
let cpuBefore = NativeProcessReader.observation(getpid())!
let burstDeadline = ProcessInfo.processInfo.systemUptime + 0.15
var accumulator: UInt64 = 1
while ProcessInfo.processInfo.systemUptime < burstDeadline { accumulator = accumulator &* 1664525 &+ 1013904223 }
let cpuAfter = NativeProcessReader.observation(getpid())!
getrusage(RUSAGE_SELF, &burstAfter)
func seconds(_ value: rusage) -> Double {
    Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) + Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec) / 1_000_000
}
let referenceSeconds = seconds(burstAfter) - seconds(burstBefore)
let nativeSeconds = Double(cpuAfter.cpuNanoseconds! - cpuBefore.cpuNanoseconds!) / 1_000_000_000
check(accumulator != 0 && referenceSeconds > 0.03 && abs(nativeSeconds - referenceSeconds) < 0.025,
      "native CPU clock matches a real getrusage burst in seconds")
let diagnosis = ResourceDiagnostics.collect(warmup: 0.1)
let diagnosisJSON = object(try CLIOutput.json(diagnosis, pretty: false))
check(diagnosis.ok && !diagnosis.groups.isEmpty && diagnosisJSON["ok"] as? Bool == true
      && diagnosisJSON["advice"] is [String], "live diagnosis is encoded with coverage and advice")
let groupJSON = object(try CLIOutput.json(ownGroup, pretty: false))
let processesJSON = groupJSON["processes"] as? [[String: Any]] ?? []
check(groupJSON["footprintBytes"] as? Int == 30 && groupJSON["missingCPUCount"] as? Int == 1
      && processesJSON.allSatisfy { $0["token"] is String }, "JSON includes aggregate counters, missing coverage and stable action tokens")
// Automatic care must conserve work and avoid turning a single large reading into a restart.
let careNow = Date(timeIntervalSince1970: 2000)
let careContext = CareContext(userID: 501, idleSeconds: 180, foregroundBundle: nil)
func careGroup(_ name: String, memory: UInt64? = 3 * 1_073_741_824, cpu: Double? = 1,
               uid: UInt32 = 501, start: UInt64 = 1) -> ResourceGroup {
    let path = "/Applications/\(name).app/Contents/MacOS/\(name)"
    return ResourceGroup(id: name, name: name, bundlePath: ResourceDiagnostics.outerBundle(path), processes: [
        ProcessUsage(identity: ProcessIdentity(pid: 29000, startSeconds: start, startMicroseconds: 0, executablePath: path, userID: uid),
                     name: name, footprintBytes: memory, cpuPercent: cpu)])
}
func careDiagnosis(_ groups: [ResourceGroup], pressure: String = "偏高", errors: [String] = []) -> ResourceDiagnosis {
    let system = MetricsSnapshot(sampledAt: careNow, cpuPercent: 25,
        memory: MemoryReading(totalBytes: 16 * 1_073_741_824, usedBytes: 13 * 1_073_741_824,
                              compressedBytes: 0, swapUsedBytes: 0, pressure: pressure), disk: fixtureDisk, errors: [])
    return ResourceDiagnosis(sampledAt: careNow, system: system, sampleSeconds: 1, groups: groups,
                             enumeratedProcessCount: groups.count, unreadableIdentityCount: 0, errors: errors)
}
let managedGroup = careGroup("Shadowrocket")
let careFixture = careDiagnosis([managedGroup])
var careHistory = CareJournal()
CarePlanner.observe(careFixture, journal: &careHistory, userID: 501, now: careNow.addingTimeInterval(-120))
let enabledCare = CarePolicy(enabled: true)
func careReady(_ value: ResourceDiagnosis = careFixture, policy: CarePolicy = enabledCare,
               history: CareJournal = careHistory, context: CareContext = careContext, batch: Bool = false) -> Bool {
    !CarePlanner.report(value, policy: policy, journal: history, context: context, now: careNow, batch: batch).ready.isEmpty
}
check(!CarePolicy().enabled && !careReady(policy: CarePolicy()), "public installs require one policy opt-in")
check(careReady(), "sustained high footprint, pressure and idle may schedule the allowed adapter")
check(!careReady(history: CareJournal()), "one high reading cannot trigger automatic restart")
check(!careReady(careDiagnosis([careGroup("Shadowrocket", start: 2)])), "reused PID invalidates historical high-memory evidence")
check(!careReady(careDiagnosis([careGroup("Shadowrocket", memory: nil)]))
      && !careReady(careDiagnosis([careGroup("Shadowrocket", cpu: nil)])), "incomplete memory or CPU coverage stops care")
check(!careReady(careDiagnosis([careGroup("Shadowrocket", uid: 502)])), "care never targets another user")
check(!careReady(careDiagnosis([careGroup("Shadowrocket", cpu: 10)])), "busy background service is preserved")
check(!careReady(context: CareContext(userID: 501, idleSeconds: nil, foregroundBundle: nil))
      && !careReady(context: CareContext(userID: 501, idleSeconds: 119, foregroundBundle: nil)), "unknown or recent input prevents automatic action")
check(!careReady(context: CareContext(userID: 501, idleSeconds: 180, foregroundBundle: managedGroup.bundlePath)), "frontmost service is preserved")
check(!careReady(careDiagnosis([managedGroup], pressure: "正常"))
      && !careReady(careDiagnosis([managedGroup], pressure: "未知"))
      && !careReady(careDiagnosis([managedGroup], errors: ["unavailable"])), "normal, unknown pressure or failed diagnosis prevents care")
check(!careReady(careDiagnosis([careGroup("OrbStack", memory: 1_500_000_000)])), "ordinary VM footprint is retained")
let protectedReport = CarePlanner.report(careDiagnosis([careGroup("aTrustAgent"), careGroup("Dia"), careGroup("Sift")]),
    policy: enabledCare, journal: careHistory, context: careContext, now: careNow, batch: true)
check(protectedReport.ready.isEmpty && protectedReport.suggestions.first(where: { $0.name == "aTrustAgent" })?.state == "ignored"
      && protectedReport.suggestions.first(where: { $0.name == "Sift" })?.state == "keep", "aTrust, browsers and indexers never enter automatic adapters")
var cooling = careHistory
cooling.events = [CareEvent(at: careNow.addingTimeInterval(-3599), service: .shadowrocket, ok: true, message: "done", beforeBytes: nil, afterBytes: nil)]
check(!careReady(history: cooling, batch: true), "even an explicit batch observes successful-action cooldown")
cooling.events = [CareEvent(at: careNow.addingTimeInterval(-21599), service: .shadowrocket, ok: false, message: "failed", beforeBytes: nil, afterBytes: nil)]
check(!careReady(history: cooling), "failed adapter pauses automatic retries for six hours")
check(careReady(history: CareJournal(), context: CareContext(userID: 501, idleSeconds: 0, foregroundBundle: nil), batch: true),
      "explicit batch can act without waiting for idle or a second sample")
let orderedCare = CarePlanner.report(careDiagnosis([careGroup("Dia", memory: 6 * 1_073_741_824), managedGroup]),
    policy: enabledCare, journal: careHistory, context: careContext, now: careNow)
check(orderedCare.suggestions.first?.service == .shadowrocket, "concrete managed operations precede read-only work app advice")
var careSchedule = CareSchedule()
check(!careSchedule.due(.elevated, enabled: true, uptime: 0)
      && !careSchedule.due(.elevated, enabled: true, uptime: 89)
      && careSchedule.due(.elevated, enabled: true, uptime: 90)
      && !careSchedule.due(.elevated, enabled: true, uptime: 209)
      && careSchedule.due(.elevated, enabled: true, uptime: 210), "care waits ninety seconds and limits diagnosis cadence to two minutes")
check(!careSchedule.due(.normal, enabled: true, uptime: 220)
      && !careSchedule.due(.elevated, enabled: true, uptime: 400), "normal pressure resets sustained-pressure evidence")
careSchedule.reset()
check(!careSchedule.due(.critical, enabled: true, uptime: 1000)
      && !careSchedule.due(.critical, enabled: false, uptime: 2000), "sleep reset and disabled policy prevent scans")
check(parsed(["care", "plan", "--json"]) == .care(operation: "plan", json: true, dryRun: false)
      && parsed(["care", "run", "--dry-run"]) == .care(operation: "run", json: false, dryRun: true), "care supports concrete read-only plans and previews")
check([["care", "enable"], ["care", "run"], ["care", "run", "--yes", "--dry-run"],
       ["care", "plan", "--yes"]].allSatisfy(rejected), "care mutations require explicit CLI intent")
let careDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("litegauge-care-test-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: careDirectory) }
let careStore = CareStore(directory: careDirectory)
let absentPolicy = try careStore.policy()
check(!absentPolicy.enabled, "missing policy defaults to disabled")
try careStore.setEnabled(true); try careStore.save(careHistory)
let fileMode = try FileManager.default.attributesOfItem(atPath: careDirectory.appendingPathComponent("care-policy.json").path)[.posixPermissions] as? Int
let folderMode = try FileManager.default.attributesOfItem(atPath: careDirectory.path)[.posixPermissions] as? Int
let savedPolicy = try careStore.policy(), savedJournal = try careStore.journal()
check(savedPolicy.enabled && savedJournal.points.count == 1 && fileMode == 0o600 && folderMode == 0o700,
      "policy and evidence persist locally with owner-only permissions")
var firstLease: CareLease? = try CareLease(directory: careDirectory)
var leaseBlocked = false
do { _ = try CareLease(directory: careDirectory) } catch { leaseBlocked = true }
check(firstLease != nil && leaseBlocked, "cross-process action lease excludes another action")
firstLease = nil
let nextLease = try CareLease(directory: careDirectory)
check(nextLease !== firstLease, "completed action releases its lease")
try Data("broken".utf8).write(to: careDirectory.appendingPathComponent("care-policy.json"))
var corruptRejected = false
do { _ = try careStore.policy() } catch { corruptRejected = true }
check(corruptRejected, "unreadable policy fails closed instead of silently enabling automation")
print("PASS \(checks) checks")
