import AppKit

final class DiagnosticViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let summary = NSTextField(wrappingLabelWithString: "点击刷新，检查当前资源占用。")
    private let advice = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "下面的进程列表可用于核对；建议和后台处理不需要逐个选择。")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let table = NSTableView()
    private let sortControl = NSSegmentedControl(labels: ["按内存", "按 CPU"], trackingMode: .selectOne, target: nil, action: nil)
    private let refreshButton = NSButton(title: "刷新诊断", target: nil, action: nil)
    private let autoButton = NSButton(title: "开启自动处理…", target: nil, action: nil)
    private let batchButton = NSButton(title: "按建议处理", target: nil, action: nil)
    private let autoState = NSTextField(wrappingLabelWithString: "")
    private let work = DispatchQueue(label: "cyou.tianli.litegauge.diagnosis", qos: .utility)
    private(set) var diagnosis: ResourceDiagnosis?
    private(set) var rows: [ResourceGroup] = []
    private(set) var busy = false
    var recommendationsWithoutSelection: Bool { !advice.stringValue.isEmpty && table.selectedRow == -1 }
    var batchWithoutSelection: Bool { batchButton.isEnabled && table.selectedRow == -1 }
    private var selectedGroup: ResourceGroup? { rows.indices.contains(table.selectedRow) ? rows[table.selectedRow] : nil }

    override func loadView() {
        let root = NSBox(frame: NSRect(x: 0, y: 0, width: 740, height: 740))
        root.boxType = .custom; root.borderWidth = 0; root.fillColor = .windowBackgroundColor
        root.contentViewMargins = .zero
        view = root
        let content = root.contentView!
        let heading = NSTextField(labelWithString: "建议操作，后台自动处理")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        summary.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        advice.font = .systemFont(ofSize: 12); advice.textColor = .secondaryLabelColor
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 12)
        sortControl.selectedSegment = 0; sortControl.target = self; sortControl.action = #selector(sortChanged)
        refreshButton.target = self; refreshButton.action = #selector(refresh)
        refreshButton.keyEquivalent = "r"; refreshButton.keyEquivalentModifierMask = .command
        autoButton.target = self; autoButton.action = #selector(toggleAutomatic)
        batchButton.target = self; batchButton.action = #selector(runRecommendations)
        autoState.font = .systemFont(ofSize: 11); autoState.textColor = .secondaryLabelColor
        let toolbar = NSStackView(views: [sortControl, NSView(), refreshButton]); toolbar.orientation = .horizontal
        for (name, title, width) in [("app", "应用 / 后台进程", 330.0), ("memory", "内存", 112.0), ("cpu", "CPU · 单核 100%", 134.0), ("count", "进程", 70.0)] {
            let column = NSTableColumn(identifier: .init(name)); column.title = title; column.width = width
            column.minWidth = name == "app" ? 120 : 55
            table.addTableColumn(column)
        }
        table.delegate = self; table.dataSource = self; table.rowHeight = 27
        table.usesAlternatingRowBackgroundColors = true; table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let buttons = NSStackView(views: [autoButton, batchButton, NSView()]); buttons.orientation = .horizontal
        let note = NSTextField(wrappingLabelWithString: "自动处理只覆盖已允许的 Shadowrocket / OrbStack；aTrust 和工作应用保留。压力持续偏高且你空闲时检查，动作后复查并暂停重复操作。进程内存不能相加当作物理 RAM。")
        note.font = .systemFont(ofSize: 10); note.textColor = .tertiaryLabelColor
        let stack = NSStackView(views: [heading, summary, buttons, autoState, advice, toolbar, scroll, detail, status, note])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            detail.heightAnchor.constraint(equalToConstant: 66), status.heightAnchor.constraint(greaterThanOrEqualToConstant: 18)
        ])
        for sub in [summary, advice, toolbar, scroll, detail, buttons, autoState, status, note] {
            sub.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        batchButton.isEnabled = false
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row), let column = tableColumn else { return nil }
        let group = rows[row], value: String
        switch column.identifier.rawValue {
        case "memory": value = DiagnosticFormat.memory(group)
        case "cpu": value = DiagnosticFormat.cpu(group)
        case "count": value = String(group.processes.count)
        default: value = group.name
        }
        let field = NSTextField(labelWithString: value)
        field.font = .systemFont(ofSize: 12, weight: column.identifier.rawValue == "app" ? .medium : .regular)
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = value
        return field
    }
    func tableViewSelectionDidChange(_ notification: Notification) { updateSelection() }

    private func updateSelection() {
        guard let group = selectedGroup else {
            detail.stringValue = "下面的进程列表可用于核对；建议和后台处理不需要逐个选择。"; return
        }
        let processLines = group.processes.prefix(3).map {
            "\($0.name) · PID \($0.identity.pid) · \($0.footprintBytes.map(DiagnosticFormat.bytes) ?? "—") · CPU \($0.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—")"
        }
        detail.stringValue = processLines.joined(separator: "\n")
    }
    func apply(_ value: ResourceDiagnosis, careReport: CareReport? = nil) {
        loadViewIfNeeded()
        diagnosis = value
        let previous = selectedGroup?.id
        rows = value.sorted(sortControl.selectedSegment == 0 ? .memory : .cpu)
        table.reloadData()
        if let previous, let row = rows.firstIndex(where: { $0.id == previous }) { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        if let m = value.system.memory {
            summary.stringValue = "内存 \(MetricFormat.gib(m.usedBytes)) / \(MetricFormat.gib(m.totalBytes)) · 压力\(m.pressure) · 压缩 \(MetricFormat.gib(m.compressedBytes)) · 交换 \(m.swapUsedBytes.map(MetricFormat.gib) ?? "—")"
        } else { summary.stringValue = "系统内存读数不可用" }
        do {
            let report = try careReport ?? CareRuntime.preview(value)
            advice.stringValue = report.lines.prefix(5).joined(separator: "\n")
            autoButton.title = report.enabled ? "暂停自动处理" : "开启自动处理…"
            batchButton.isEnabled = !busy && report.enabled
            autoState.stringValue = report.enabled ? "自动处理已开启 · 无需逐个点选，压力持续偏高时安排后台任务" : "自动处理未开启 · 首次允许后，后台任务按规则处理"
        } catch {
            advice.stringValue = "操作策略不可读，自动处理已暂停。"
            batchButton.isEnabled = false
        }
        if !value.errors.isEmpty { status.stringValue = value.errors.joined(separator: "；") }
        else if status.stringValue.isEmpty || status.stringValue.hasPrefix("正在") {
            let clock = DateFormatter(); clock.dateFormat = "HH:mm:ss"
            status.stringValue = "\(clock.string(from: value.sampledAt)) · 读取 \(value.groups.flatMap(\.processes).count) 个进程，\(value.unreadableIdentityCount) 个身份不可读 · 用时 \(String(format: "%.1f", value.sampleSeconds)) 秒"
        }
        updateSelection()
    }
    private func setBusy(_ value: Bool) {
        busy = value; refreshButton.isEnabled = !value; sortControl.isEnabled = !value
        autoButton.isEnabled = !value
        batchButton.isEnabled = !value && ((try? CareStore().policy().enabled) == true)
        updateSelection()
    }
    @objc func refresh() {
        guard !busy else { return }
        setBusy(true); status.stringValue = "正在采样资源占用…"
        work.async { [weak self] in
            let result = ResourceDiagnostics.collect()
            DispatchQueue.main.async { guard let self else { return }; self.setBusy(false); self.apply(result) }
        }
    }
    @objc private func sortChanged() { if let diagnosis { apply(diagnosis) } }
    @objc private func toggleAutomatic() {
        guard !busy else { return }
        do {
            let store = CareStore()
            if try store.policy().enabled { try store.setEnabled(false); if let diagnosis { apply(diagnosis) }; return }
            guard let window = view.window else { return }
            let alert = NSAlert(); alert.messageText = "允许后台自动处理？"
            alert.informativeText = "一次允许 Shadowrocket 重连隧道、OrbStack 正常重启虚拟机后台；网络或容器会短暂中断。仅在持续高占用、内存压力偏高且你空闲时执行，完成后复查并保留结果。aTrust、工作应用和正常占用保留。"
            alert.addButton(withTitle: "允许自动处理"); alert.addButton(withTitle: "取消")
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn, let self else { return }
                do { try store.setEnabled(true); if let diagnosis = self.diagnosis { self.apply(diagnosis) } }
                catch { self.status.stringValue = error.localizedDescription }
            }
        } catch { status.stringValue = (error as? ResourceActionError)?.message ?? error.localizedDescription }
    }
    @objc private func runRecommendations() {
        guard !busy else { return }
        setBusy(true); status.stringValue = "正在按建议处理并复查…"
        work.async { [weak self] in
            let result = Result { try CareRuntime.run(batch: true, dryRun: false) }
            let fresh = ResourceDiagnostics.collect()
            DispatchQueue.main.async {
                guard let self else { return }; self.setBusy(false); self.apply(fresh)
                switch result {
                case .success(let value): self.status.stringValue = value.message
                case .failure(let error): self.status.stringValue = (error as? ResourceActionError)?.message ?? error.localizedDescription
                }
            }
        }
    }
}

final class DiagnosticWindowController: NSWindowController, NSWindowDelegate {
    let diagnosticView = DiagnosticViewController()
    var didClose: (() -> Void)?
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "LiteGauge · 资源建议与自动处理"; window.minSize = NSSize(width: 660, height: 700)
        window.contentViewController = diagnosticView; window.delegate = self; window.isReleasedWhenClosed = false
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); diagnosticView.refresh() }
    func windowWillClose(_ notification: Notification) { didClose?() }
}
