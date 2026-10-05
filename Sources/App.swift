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

/// Other processes of this bundle than the calling one.
enum RunningInstances {
    /// Every other process with the bundle id: the single-instance guard uses this (unchanged since 0.1.0).
    static func others() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: AppIdentity.bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }

    /// Only instances that own a status item: the App runs as .accessory and creates the item once launching finishes.
    /// The offscreen --ui-self-test and --snapshot runs never call NSApp.run (so never finish launching) and switch to
    /// .prohibited; they start out .accessory from LSUIElement for a few ms, hence both conditions. `app status` and
    /// `app quit` use this, so acceptance runs are never listed or signalled.
    static func menuBar() -> [NSRunningApplication] {
        others().filter { $0.activationPolicy == .accessory && $0.isFinishedLaunching }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let queue = DispatchQueue(label: "cyou.tianli.litegauge.sampler", qos: .utility)
    private let sampler = MetricsSampler()
    fileprivate var timer: DispatchSourceTimer?
    fileprivate var latest: MetricsSnapshot?
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var samplingState = SamplingState()
    private let benchmark: String?
    private let launchTime = ProcessInfo.processInfo.systemUptime
    private var didReportReady = false
    private var menuOpen = false
    fileprivate var lastTitle = ""
    private let summary = SummaryView(frame: NSRect(x: 0, y: 0, width: 304, height: 276))
    private var diagnosticWindow: DiagnosticWindowController?
    private var automaticCare: AutomaticCareController?
    private var terminationDeferred = false
    private var careStatusItem: NSMenuItem?
    private var quitAfterCare = false

    init(benchmark: String?) { self.benchmark = benchmark }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if benchmark == nil, !RunningInstances.others().isEmpty {
            NSApp.terminate(nil)
            return
        }
        if benchmark == nil {
            AppLifecycleUI.install(name: "LiteGauge · 极简菜单栏监控", configuration: nil, updateSource: .github(repository: "zengtianli/LiteGauge"))
        }
        statusItem = NSStatusBar.system.statusItem(withLength: StatusRenderer.size.width)
        statusItem.button?.image = StatusRenderer.image(cpu: nil, memory: nil, disk: nil)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.toolTip = "从左到右：CPU、内存、磁盘已用比例 · 点击查看数值"
        statusItem.button?.setAccessibilityLabel("轻仪：CPU、内存、磁盘")
        buildMenu()
        statusItem.menu = menu
        if benchmark == nil {
            let care = AutomaticCareController()
            care.changed = { [weak self] text in self?.careStatusItem?.title = text }
            care.finished = { [weak self] in
                guard let self else { return }
                if self.terminationDeferred { NSApp.reply(toApplicationShouldTerminate: true) }
                else if self.quitAfterCare { NSApp.terminate(nil) }
                else { self.diagnosticWindow?.diagnosticView.refresh() }
            }
            automaticCare = care; care.start()
        }
        startObservingSleep()
        requestSample(forceDisk: true)
        startTimer()
    }

    private func buildMenu() {
        menu.delegate = self
        let panel = NSMenuItem()
        panel.view = summary
        menu.addItem(panel)
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        let diagnose = NSMenuItem(title: "资源建议与自动处理…", action: #selector(openDiagnosis), keyEquivalent: "")
        diagnose.target = self
        menu.addItem(diagnose)
        let careStatus = NSMenuItem(title: "自动处理未开启", action: nil, keyEquivalent: "")
        careStatus.isEnabled = false; careStatusItem = careStatus; menu.addItem(careStatus)
        let activity = NSMenuItem(title: "打开活动监视器…", action: #selector(openActivityMonitor), keyEquivalent: "")
        activity.target = self
        menu.addItem(activity)
        if benchmark == nil { AppLifecycleUI.menuItems().forEach { menu.addItem($0) } }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出轻仪", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func startObservingSleep() {
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
    }

    private func startTimer() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + .seconds(1), repeating: MetricsSampler.sampleInterval, leeway: .milliseconds(200))
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
        automaticCare?.sample(snapshot)
        let title = MetricFormat.status(snapshot)
        if lastTitle != title {
            lastTitle = title
            statusItem?.button?.image = StatusRenderer.image(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, disk: snapshot.disk?.usedPercent)
            statusItem?.button?.setAccessibilityValue(title)
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
            automaticCare?.suspend()
            timer?.cancel()
            timer = nil
        }
    }

    @objc private func refreshNow() { requestSample(forceDisk: true) }
    @objc private func openDiagnosis() {
        if diagnosticWindow == nil {
            let controller = DiagnosticWindowController()
            controller.didClose = { [weak self] in self?.diagnosticWindow = nil }
            diagnosticWindow = controller
        }
        diagnosticWindow?.present()
    }
    @objc private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
    @objc private func quit() { requestQuit() }
    func requestQuit() {
        if automaticCare?.isHandling == true {
            quitAfterCare = true; automaticCare?.suspend()
            careStatusItem?.title = "完成后台恢复后退出轻仪"
        } else { NSApp.terminate(nil) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard automaticCare?.isHandling == true else { return .terminateNow }
        terminationDeferred = true; automaticCare?.suspend()
        careStatusItem?.title = "完成后台恢复后退出轻仪"
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.cancel()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }
}

final class SummaryView: NSView {
    private(set) var snapshot: MetricsSnapshot?
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
            let color: NSColor
            switch m.level {
            case .critical: color = .systemRed
            case .warning: color = .systemOrange
            case .normal: color = .systemGreen
            }
            bar(m.percent, 115, color: color)
            text("压力\(m.pressure) · 交换 \(m.swapUsedBytes.map(MetricFormat.gib) ?? "—")", 18, 126, size: 11, color: secondary)
        } else { text(snapshot == nil ? "读取中…" : "不可用", 215, 89, color: secondary) }
        text("启动磁盘", 18, 161, weight: .medium)
        if let d = snapshot?.disk {
            text("剩余 \(MetricFormat.gb(d.availableBytes))", 171, 161, weight: .medium)
            bar(d.usedPercent, 187, color: d.level == .warning ? .systemOrange : .systemBlue)
            text("总容量 \(MetricFormat.gb(d.totalBytes))", 18, 198, size: 11, color: secondary)
        } else { text(snapshot == nil ? "读取中…" : "不可用", 215, 161, color: secondary) }
        let note = snapshot?.errors.isEmpty == false ? snapshot!.errors.joined(separator: " · ") : MetricFormat.cadence
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

// In-process UI self-test: the real menu, panel and indicator are built offscreen and their action
// code paths are called directly. No status item, visible window, focus change or synthesized input.
extension AppDelegate {
    func runUISelfTest(outDir: URL) -> Bool {
        var checks: [String: Bool] = [:]
        func wait(_ seconds: Double, until done: () -> Bool) -> Bool {
            let end = Date().addingTimeInterval(seconds)
            while !done() && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            return done()
        }
        func png(_ view: NSView, _ name: String) -> Int {
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: outDir.appendingPathComponent(name))
            var ink = 0
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) { for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                if let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.1 { ink += 1 } } }
            return ink
        }
        summary.appearance = NSAppearance(named: .aqua)
        buildMenu()
        let items = menu.items
        let refresh = items.first { $0.title == "立即刷新" }, quit = items.first { $0.title == "退出轻仪" }
        let activity = items.first { $0.title == "打开活动监视器…" }
        let diagnose = items.first { $0.title == "资源建议与自动处理…" }
        checks["menu_structure"] = items.count >= 7 && items[0].view === summary && items.last === quit
            && ["立即刷新", "退出轻仪", "打开活动监视器…", "资源建议与自动处理…"].allSatisfy { title in items.filter { $0.title == title }.count == 1 }
        checks["shortcuts_cmd_r_q"] = refresh?.keyEquivalent == "r" && quit?.keyEquivalent == "q"
            && refresh?.keyEquivalentModifierMask == .command && quit?.keyEquivalentModifierMask == .command
        checks["actions_wired"] = [refresh, quit, activity, diagnose].allSatisfy { item in
            guard let item, let action = item.action, let target = item.target as? NSObject else { return false }
            return target === self && target.responds(to: action) }
        checks["panel_initial_reading"] = summary.snapshot == nil && png(summary, "native-ui-panel-initial.png") > 0

        // Opening the menu: AppKit calls menuWillOpen, which shows the latest reading and forces a sample.
        menuWillOpen(menu)
        checks["open_samples_panel"] = wait(5) { summary.snapshot?.memory != nil && summary.snapshot?.disk != nil }
        let firstDisk = summary.snapshot?.disk?.sampledAt
        Thread.sleep(forTimeInterval: 1.1)
        // "立即刷新" (⌘R) dispatches this action; call it the same way AppKit's menu would.
        if let refresh, let action = refresh.action { NSApp.sendAction(action, to: refresh.target, from: refresh) }
        checks["refresh_updates_cpu_and_disk"] = wait(5) {
            summary.snapshot?.cpuPercent != nil && (summary.snapshot?.disk?.sampledAt ?? .distantPast) > (firstDisk ?? .distantFuture) }
        let label = summary.accessibilityLabel() ?? ""
        checks["panel_accessibility_values"] = label.contains("CPU") && label.contains("内存") && label.contains("磁盘剩余")
        checks["panel_renders"] = png(summary, "native-ui-panel.png") > 1000
        checks["indicator_tracks_reading"] = lastTitle == MetricFormat.status(latest!) && lastTitle.contains("%")

        // Closing the menu stops panel updates; the indicator keeps updating.
        menuDidClose(menu)
        let frozen = summary.snapshot?.sampledAt
        let before = latest?.sampledAt
        Thread.sleep(forTimeInterval: 0.2)
        requestSample(forceDisk: false)
        checks["closed_menu_stops_panel_updates"] = wait(5) { latest?.sampledAt != before } && summary.snapshot?.sampledAt == frozen

        // Sleep, screen sleep and lock each pause sampling; sampling resumes only when all clear.
        startTimer()
        setPaused(true, reason: "lock"); setPaused(true, reason: "screen")
        let paused = timer == nil
        setPaused(false, reason: "screen")
        let stillPaused = timer == nil
        setPaused(false, reason: "lock")
        checks["pause_resume"] = paused && stillPaused && timer != nil
        timer?.cancel(); timer = nil

        // Indicator: empty vs full bars differ in drawn ink; unavailable readings still draw the outline.
        func indicator(_ c: Double?, _ m: Double?, _ d: Double?, _ name: String) -> Int {
            let view = NSImageView(frame: NSRect(origin: .zero, size: StatusRenderer.size))
            view.image = StatusRenderer.image(cpu: c, memory: m, disk: d)
            view.imageScaling = .scaleNone
            return png(view, name)
        }
        let empty = indicator(0, 0, 0, "native-ui-indicator-0.png"), full = indicator(100, 100, 100, "native-ui-indicator-100.png")
        let none = indicator(nil, nil, nil, "native-ui-indicator-unavailable.png")
        checks["indicator_bars_scale"] = full > empty && empty > 0 && none > 0

        let diagnosis = ResourceDiagnostics.collect()
        let diagnosticLayoutWindow = DiagnosticWindowController()
        let diagnosticView = diagnosticLayoutWindow.diagnosticView
        diagnosticView.view.appearance = NSAppearance(named: .aqua)
        diagnosticView.apply(diagnosis)
        diagnosticView.view.layoutSubtreeIfNeeded()
        checks["diagnosis_live_groups"] = diagnosis.ok && !diagnosticView.rows.isEmpty
        checks["diagnosis_offscreen_renders"] = png(diagnosticView.view, "native-ui-diagnosis.png") > 1000
        checks["diagnosis_preview_does_not_act"] = !diagnosticView.busy && diagnosticWindow == nil
        let report = CareReport(enabled: true, checkedAt: Date(), suggestions: [
            CareSuggestion(name: "示例浏览器", state: "ready", message: "示例浏览器：可立即恢复重启。", service: .dia, target: nil)
        ])
        diagnosticView.apply(diagnosis, careReport: report)
        checks["recommendations_without_row_selection"] = diagnosticView.recommendationsWithoutSelection
        checks["combined_action_without_row_selection"] = diagnosticView.batchWithoutSelection
        var invoked = false
        diagnosticView.recommendationRunner = {
            invoked = true
            let event = CareEvent(at: Date(), service: .dia, ok: true, message: "示例处理已完成。", beforeBytes: 3_000_000_000, afterBytes: 1_000_000_000)
            return CareRunResult(ok: true, report: report, actions: [event], message: event.message)
        }
        diagnosticView.activateRecommendationsForTest()
        checks["recommendation_button_invokes_runner"] = wait(5) { !diagnosticView.busy } && invoked
        checks["recommendation_result_visible_at_top"] = diagnosticView.operationOutcome.contains("已处理 1 项")
        diagnosticView.apply(diagnosis, careReport: report)
        diagnosticView.recommendationRunner = { CareRunResult(ok: false, report: report, actions: [], message: "本次处理 0 项。示例条件已变化。") }
        diagnosticView.activateRecommendationsForTest()
        checks["recommendation_zero_actions_explained"] = wait(5) { !diagnosticView.busy } && diagnosticView.operationOutcome.contains("处理 0 项")
        let noReady = CareReport(enabled: false, checkedAt: Date(), suggestions: [])
        diagnosticView.apply(diagnosis, careReport: noReady, carePolicy: CarePolicy(enabled: false, services: CareService.allCases))
        checks["paused_manual_recheck_is_enabled_without_ready_items"] = diagnosticView.batchWithoutSelection
        diagnosticView.apply(diagnosis, careReport: noReady, carePolicy: CarePolicy())
        checks["missing_consent_keeps_manual_action_disabled"] = !diagnosticView.batchWithoutSelection
        diagnosticView.apply(diagnosis, careReport: report)
        diagnosticView.recommendationRunner = {
            let events = [CareService.dia, .chrome].map { CareEvent(at: Date(), service: $0, ok: true, message: "示例处理已完成。", beforeBytes: 3_000_000_000, afterBytes: 1_000_000_000) }
            return CareRunResult(ok: true, report: report, actions: events, message: "示例批量处理完成。", deferred: ["示例服务：条件变化，略过。"])
        }
        diagnosticView.activateRecommendationsForTest()
        checks["one_click_displays_all_results_and_deferrals"] = wait(5) { !diagnosticView.busy }
            && diagnosticView.operationOutcome.contains("已处理 2 项") && diagnosticView.operationOutcome.contains("Google Chrome")
            && diagnosticView.operationOutcome.contains("条件变化，略过")
        checks["recommendation_outcome_fits_visible_panel"] = diagnosticView.operationOutcomeVisible
        _ = png(diagnosticView.view, "native-ui-recommendation-result.png")

        let ok = checks.values.allSatisfy { $0 }
        let result: [String: Any] = ["ok": ok, "checks": checks, "screenshots": ["native-ui-panel-initial.png", "native-ui-panel.png",
            "native-ui-indicator-0.png", "native-ui-indicator-100.png", "native-ui-indicator-unavailable.png", "native-ui-diagnosis.png", "native-ui-recommendation-result.png"],
            "not_covered": ["physical menu-bar click and AppKit menu tracking", "opening Activity Monitor", "actual quit", "real sleep/wake notifications"]]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .sortedKeys) { print(String(decoding: data, as: UTF8.self)) }
        return ok
    }
}
