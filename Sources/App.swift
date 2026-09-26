import AppKit
import CoreText

enum StatusRenderer {
    static let size = NSSize(width: 56, height: 18)
    private static let labelFont = NSFont.systemFont(ofSize: 6.5, weight: .medium)
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)

    // Send a prepared template bitmap to AppKit; each menu-bar replica can reuse it.
    static func image(cpu: Double?, memory: Double?, disk: Double?) -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 112, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = size
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
        // NSGraphicsContext already applies bitmap.size's 2× backing scale.
        draw(cpu: cpu, memory: memory, disk: disk, in: context, color: .black)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        image.isTemplate = true
        return image
    }

    static func draw(cpu: Double?, memory: Double?, disk: Double?, in context: CGContext, color: NSColor) {
        func centeredText(_ text: String, font: NSFont, baseline: CGFloat) {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: color]))
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            context.saveGState()
            let scale = min(1, 29 / max(1, width))
            context.translateBy(x: (29 - width * scale) / 2, y: baseline)
            context.scaleBy(x: scale, y: 1)
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
        func bar(_ value: Double?, x: CGFloat) {
            let outline = CGRect(x: x + 0.5, y: 1.5, width: 7, height: 15)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1)
            context.addPath(CGPath(roundedRect: outline, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            context.strokePath()
            if let value {
                let height = (13 * min(100, max(0, value)) / 100 * 2).rounded() / 2
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: x + 1.5, y: 2.5, width: 5, height: height))
            }
        }
        centeredText("CPU", font: labelFont, baseline: 11.5)
        centeredText(MetricFormat.percent(cpu), font: valueFont, baseline: 1)
        bar(memory, x: 32)
        bar(disk, x: 45)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let queue = DispatchQueue(label: "cyou.tianli.litegauge.sampler", qos: .utility)
    private let sampler = MetricsSampler()
    private var timer: DispatchSourceTimer?
    private var latest: MetricsSnapshot?
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var samplingState = SamplingState()
    private let benchmark: String?
    private let launchTime = ProcessInfo.processInfo.systemUptime
    private var didReportReady = false
    private var menuOpen = false
    private var lastTitle = ""
    private let summary = SummaryView(frame: NSRect(x: 0, y: 0, width: 304, height: 276))

    init(benchmark: String?) { self.benchmark = benchmark }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if benchmark == nil,
           NSRunningApplication.runningApplications(withBundleIdentifier: "cyou.tianli.litegauge")
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: StatusRenderer.size.width)
        statusItem.button?.image = StatusRenderer.image(cpu: nil, memory: nil, disk: nil)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.toolTip = "从左到右：CPU、内存、磁盘已用比例 · 点击查看数值"
        statusItem.button?.setAccessibilityLabel("轻仪：CPU、内存、磁盘")
        menu.delegate = self
        let panel = NSMenuItem()
        panel.view = summary
        menu.addItem(panel)
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        let activity = NSMenuItem(title: "打开活动监视器…", action: #selector(openActivityMonitor), keyEquivalent: "")
        activity.target = self
        menu.addItem(activity)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出轻仪", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        let center = NSWorkspace.shared.notificationCenter
        for (name, reason) in [(NSWorkspace.willSleepNotification, "sleep"), (NSWorkspace.screensDidSleepNotification, "screen")] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.setPaused(true, reason: reason) })
        }
        for (name, reason) in [(NSWorkspace.didWakeNotification, "sleep"), (NSWorkspace.screensDidWakeNotification, "screen")] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.setPaused(false, reason: reason) })
        }
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.setPaused(true, reason: "lock") })
        distributedObservers.append(distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.setPaused(false, reason: "lock") })
        requestSample(forceDisk: true)
        startTimer()
    }

    private func startTimer() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + .seconds(1), repeating: .seconds(2), leeway: .milliseconds(200))
        source.setEventHandler { [weak self] in self?.takeSample(forceDisk: false) }
        timer = source
        source.resume()
    }

    private func requestSample(forceDisk: Bool) {
        queue.async { [weak self] in self?.takeSample(forceDisk: forceDisk) }
    }

    private func takeSample(forceDisk: Bool) {
        let snapshot = sampler.sample(forceDisk: forceDisk)
        DispatchQueue.main.async { [weak self] in self?.apply(snapshot) }
    }

    private func apply(_ snapshot: MetricsSnapshot) {
        latest = snapshot
        let title = MetricFormat.status(snapshot)
        if lastTitle != title {
            lastTitle = title
            statusItem.button?.image = StatusRenderer.image(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, disk: snapshot.disk?.usedPercent)
            statusItem.button?.setAccessibilityValue(title)
        }
        if menuOpen { summary.update(snapshot) }
        if !didReportReady, snapshot.cpuPercent != nil {
            didReportReady = true
            if let benchmark {
                let data: [String: Any] = ["ready_ms": (ProcessInfo.processInfo.systemUptime - launchTime) * 1000,
                                          "pid": ProcessInfo.processInfo.processIdentifier]
                if let bytes = try? JSONSerialization.data(withJSONObject: data, options: .sortedKeys) {
                    try? bytes.write(to: URL(fileURLWithPath: benchmark), options: .atomic)
                }
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        if let latest { summary.update(latest) }
        requestSample(forceDisk: true)
    }

    func menuDidClose(_ menu: NSMenu) { menuOpen = false }

    private func setPaused(_ paused: Bool, reason: String) {
        let wasRunning = samplingState.isRunning
        samplingState.setPaused(paused, reason: reason)
        guard wasRunning != samplingState.isRunning else { return }
        if samplingState.isRunning {
            queue.async { [weak self] in self?.sampler.resetCPU() }
            requestSample(forceDisk: true)
            startTimer()
        } else {
            timer?.cancel()
            timer = nil
        }
    }

    @objc private func refreshNow() { requestSample(forceDisk: true) }
    @objc private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.cancel()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }
}

final class SummaryView: NSView {
    private var snapshot: MetricsSnapshot?
    override var isFlipped: Bool { true }

    func update(_ snapshot: MetricsSnapshot) {
        self.snapshot = snapshot
        needsDisplay = true
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(accessibilityText(snapshot))
    }

    private func accessibilityText(_ s: MetricsSnapshot) -> String {
        var parts = ["轻仪", "CPU \(MetricFormat.percent(s.cpuPercent))"]
        if let m = s.memory { parts.append("内存 \(MetricFormat.gib(m.usedBytes))，压力\(m.pressure)") }
        if let d = s.disk { parts.append("磁盘剩余 \(MetricFormat.gb(d.availableBytes))") }
        return parts.joined(separator: "，")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let titleColor = NSColor.labelColor
        let secondary = NSColor.secondaryLabelColor
        func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 12,
                  weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
            (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        }
        func bar(_ value: Double?, _ y: CGFloat, color: NSColor) {
            let rect = NSRect(x: 18, y: y, width: 268, height: 4)
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
            if let value {
                color.setFill()
                NSBezierPath(roundedRect: NSRect(x: 18, y: y, width: 268 * min(1, max(0, value / 100)), height: 4), xRadius: 2, yRadius: 2).fill()
            }
        }
        text("轻仪", 18, 10, size: 14, weight: .semibold)
        text("LiteGauge", 225, 12, size: 10, color: secondary)
        text("CPU", 18, 44, weight: .medium)
        text(MetricFormat.percent(snapshot?.cpuPercent), 240, 40, size: 20, weight: .medium, color: titleColor)
        bar(snapshot?.cpuPercent, 70, color: .systemBlue)
        text("内存", 18, 89, weight: .medium)
        if let m = snapshot?.memory {
            text("\(MetricFormat.gib(m.usedBytes)) / \(MetricFormat.gib(m.totalBytes))", 108, 89, weight: .medium)
            let color: NSColor = m.pressure == "紧张" ? .systemRed : m.pressure == "偏高" ? .systemOrange : .systemGreen
            bar(m.percent, 115, color: color)
            text("压力\(m.pressure) · 交换 \(m.swapUsedBytes.map(MetricFormat.gib) ?? "—")", 18, 126, size: 11, color: secondary)
        } else { text(snapshot == nil ? "读取中…" : "不可用", 215, 89, color: secondary) }
        text("启动磁盘", 18, 161, weight: .medium)
        if let d = snapshot?.disk {
            text("剩余 \(MetricFormat.gb(d.availableBytes))", 171, 161, weight: .medium)
            bar(d.usedPercent, 187, color: d.usedPercent > 90 ? .systemOrange : .systemBlue)
            text("总容量 \(MetricFormat.gb(d.totalBytes))", 18, 198, size: 11, color: secondary)
        } else { text(snapshot == nil ? "读取中…" : "不可用", 215, 161, color: secondary) }
        let note = snapshot?.errors.isEmpty == false ? snapshot!.errors.joined(separator: " · ") : "每 2 秒更新 · 磁盘每 60 秒更新"
        text(note, 18, 244, size: 10, color: secondary)
    }
}

func renderSnapshot(to path: String) throws {
    let sampler = MetricsSampler()
    _ = sampler.sample()
    Thread.sleep(forTimeInterval: 1)
    let view = SummaryView(frame: NSRect(x: 0, y: 0, width: 304, height: 276))
    view.appearance = NSAppearance(named: .aqua)
    view.update(sampler.sample())
    let image = NSImage(size: view.bounds.size)
    image.lockFocus()
    NSColor.windowBackgroundColor.setFill()
    view.bounds.fill()
    view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext.current!)
    image.unlockFocus()
    guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LiteGauge", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: path))
}
