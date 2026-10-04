import AppKit

// Uses the production view and sampler. No windows, clicks, or desktop capture.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
NSApp.appearance = NSAppearance(named: .aqua)
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let frames = out.appendingPathComponent("frames", isDirectory: true)
try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)

func save(_ image: NSImage, _ url: URL) throws {
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

func panel(_ snapshot: MetricsSnapshot) -> NSImage {
    let view = SummaryView(frame: NSRect(x: 0, y: 0, width: 304, height: 276))
    view.appearance = NSAppearance(named: .aqua)
    view.update(snapshot)
    let image = NSImage(size: view.bounds.size)
    image.lockFocus()
    NSColor.windowBackgroundColor.setFill()
    view.bounds.fill()
    view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext.current!)
    image.unlockFocus()
    return image
}

let fixture = MetricsSnapshot(sampledAt: Date(timeIntervalSince1970: 0), cpuPercent: 22,
    memory: MemoryReading(totalBytes: 16 * 1_073_741_824, usedBytes: 10 * 1_073_741_824,
        compressedBytes: 1_073_741_824, swapUsedBytes: 0, pressure: "正常"),
    disk: DiskReading(volume: "/System/Volumes/Data", totalBytes: 500_000_000_000,
        availableBytes: 180_000_000_000, sampledAt: Date(timeIntervalSince1970: 0)), errors: [])
try save(panel(fixture), out.appendingPathComponent("panel.png"))
let bar = StatusRenderer.image(cpu: fixture.cpuPercent, memory: fixture.memory?.percent, disk: fixture.disk?.usedPercent)
try save(bar, out.appendingPathComponent("menubar.png"))

// Public diagnostic screenshot: deterministic examples, no local process paths or private usage history.
let exampleApps: [(String, String, UInt64, Double)] = [
    ("Browser", "/Applications/Browser.app/Contents/MacOS/Browser", 2_600_000_000, 8),
    ("OrbStack", "/Applications/OrbStack.app/Contents/MacOS/OrbStack", 1_350_000_000, 3),
    ("Shadowrocket", "/Applications/Shadowrocket.app/Contents/MacOS/Shadowrocket", 160_000_000, 1),
    ("Notes", "/Applications/Notes.app/Contents/MacOS/Notes", 90_000_000, 0.1)
]
let groups = exampleApps.enumerated().map { index, item in
    ResourceGroup(id: "example-\(index)", name: item.0, bundlePath: ResourceDiagnostics.outerBundle(item.1),
        processes: [ProcessUsage(identity: ProcessIdentity(pid: Int32(24001 + index), startSeconds: 1, startMicroseconds: 0,
            executablePath: item.1, userID: UInt32.max), name: item.0, footprintBytes: item.2, cpuPercent: item.3)])
}
let diagnosis = ResourceDiagnosis(sampledAt: fixture.sampledAt, system: fixture, sampleSeconds: 1, groups: groups,
    enumeratedProcessCount: 4, unreadableIdentityCount: 0, errors: [])
let diagnosticView = DiagnosticViewController()
diagnosticView.view.appearance = NSAppearance(named: .aqua)
diagnosticView.apply(diagnosis)
diagnosticView.view.layoutSubtreeIfNeeded()
let diagnosticRep = diagnosticView.view.bitmapImageRepForCachingDisplay(in: diagnosticView.view.bounds)!
diagnosticView.view.cacheDisplay(in: diagnosticView.view.bounds, to: diagnosticRep)
try diagnosticRep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("diagnosis.png"))

let captions = [
    ("01 / 菜单栏，一眼读懂", "左侧 CPU 百分比；右侧两根竖条依次表示内存、磁盘已用比例。"),
    ("02 / 内存，看数值也看压力", "详情同时显示内存压力和交换空间；占用高不一定代表内存不足。"),
    ("03 / 磁盘，查看剩余容量", "磁盘详情显示剩余空间；日常点击菜单或按 ⌘R 可立即刷新。")
]
let sampler = MetricsSampler()
_ = sampler.sample()
Thread.sleep(forTimeInterval: 1)
var samples: [MetricsSnapshot] = []
let started = ProcessInfo.processInfo.systemUptime
var current = sampler.sample()
for second in 0..<24 {
    let target = started + Double(second)
    let remaining = target - ProcessInfo.processInfo.systemUptime
    if remaining > 0 { Thread.sleep(forTimeInterval: remaining) }
    if second > 0 && second % 2 == 0 { current = sampler.sample() }
    samples.append(current)
    let image = NSImage(size: NSSize(width: 1280, height: 900))
    image.lockFocus()
    NSColor(calibratedRed: 0.957, green: 0.969, blue: 0.953, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1280, height: 900).fill()
    func text(_ value: String, _ y: CGFloat, _ size: CGFloat, _ color: NSColor = .labelColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color]
        let width = (value as NSString).size(withAttributes: attrs).width
        (value as NSString).draw(at: NSPoint(x: (1280 - width) / 2, y: y), withAttributes: attrs)
    }
    text("轻仪 LiteGauge · " + captions[second / 8].0, 822, 34)
    text("同源原生界面离屏演示 · 数值来自本机实时采样", 777, 21, .secondaryLabelColor)
    let status = StatusRenderer.image(cpu: current.cpuPercent, memory: current.memory?.percent, disk: current.disk?.usedPercent)
    status.draw(in: NSRect(x: 528, y: 681, width: 224, height: 72))
    text("56 pt 菜单栏指示器（放大展示）", 644, 18, .secondaryLabelColor)
    panel(current).draw(in: NSRect(x: 397, y: 184, width: 486, height: 442))
    text(captions[second / 8].1, 102, 25)
    text("本片展示数据和界面；安装与菜单操作请按网页教程完成。", 59, 19, .secondaryLabelColor)
    image.unlockFocus()
    try save(image, frames.appendingPathComponent(String(format: "%03d.png", second)))
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601
try encoder.encode(samples).write(to: out.appendingPathComponent("samples.json"))
print("Captured 24 seconds using production SummaryView, StatusRenderer, and MetricsSampler")
