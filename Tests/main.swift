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
print("PASS \(checks) checks")
