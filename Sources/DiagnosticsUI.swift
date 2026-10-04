import AppKit

final class DiagnosticViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let summary = NSTextField(wrappingLabelWithString: "点击刷新，检查当前资源占用。")
    private let advice = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "选择应用查看进程和处理方式。")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let table = NSTableView()
    private let sortControl = NSSegmentedControl(labels: ["按内存", "按 CPU"], trackingMode: .selectOne, target: nil, action: nil)
    private let refreshButton = NSButton(title: "刷新诊断", target: nil, action: nil)
    private let quitButton = NSButton(title: "正常退出…", target: nil, action: nil)
    private let restartButton = NSButton(title: "重启并复查…", target: nil, action: nil)
    private let work = DispatchQueue(label: "cyou.tianli.litegauge.diagnosis", qos: .utility)
    private(set) var diagnosis: ResourceDiagnosis?
    private(set) var rows: [ResourceGroup] = []
    private(set) var busy = false
    private var selectedGroup: ResourceGroup? { rows.indices.contains(table.selectedRow) ? rows[table.selectedRow] : nil }

    override func loadView() {
        let root = NSBox(frame: NSRect(x: 0, y: 0, width: 740, height: 640))
        root.boxType = .custom; root.borderWidth = 0; root.fillColor = .windowBackgroundColor
        root.contentViewMargins = .zero
        view = root
        let content = root.contentView!
        let heading = NSTextField(labelWithString: "找出占用，处理后复查")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        summary.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        advice.font = .systemFont(ofSize: 12); advice.textColor = .secondaryLabelColor
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 12)
        sortControl.selectedSegment = 0; sortControl.target = self; sortControl.action = #selector(sortChanged)
        refreshButton.target = self; refreshButton.action = #selector(refresh)
        refreshButton.keyEquivalent = "r"; refreshButton.keyEquivalentModifierMask = .command
        quitButton.target = self; quitButton.action = #selector(quitSelected)
        restartButton.target = self; restartButton.action = #selector(restartSelected)
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
        let buttons = NSStackView(views: [quitButton, restartButton, NSView()]); buttons.orientation = .horizontal
        let note = NSTextField(wrappingLabelWithString: "内存包含压缩及换出计账，不能相加当作物理 RAM。未知读数显示 —，部分可读显示 ≥。只在点击时扫描，不自动清缓存或结束进程。")
        note.font = .systemFont(ofSize: 10); note.textColor = .tertiaryLabelColor
        let stack = NSStackView(views: [heading, summary, advice, toolbar, scroll, detail, buttons, status, note])
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
        for sub in [summary, advice, toolbar, scroll, detail, buttons, status, note] {
            sub.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        quitButton.isEnabled = false; restartButton.isEnabled = false
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
        guard let group = selectedGroup, let member = group.processes.first else {
            detail.stringValue = "选择应用查看进程和处理方式。"; quitButton.isEnabled = false; restartButton.isEnabled = false; return
        }
        let processLines = group.processes.prefix(3).map {
            "\($0.name) · PID \($0.identity.pid) · \($0.footprintBytes.map(DiagnosticFormat.bytes) ?? "—") · CPU \($0.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—")"
        }
        let quit = try? ResourceActions.prepare(pid: member.identity.pid, token: member.token, action: "quit")
        let restart = try? ResourceActions.prepare(pid: member.identity.pid, token: member.token, action: "restart")
        detail.stringValue = processLines.joined(separator: "\n")
            + (quit == nil && restart == nil ? "\n系统或独立后台服务：请在所属应用中处理。" : "")
        quitButton.isEnabled = !busy && quit != nil; restartButton.isEnabled = !busy && restart != nil
    }
    func apply(_ value: ResourceDiagnosis) {
        loadViewIfNeeded()
        diagnosis = value
        let previous = selectedGroup?.id
        rows = value.sorted(sortControl.selectedSegment == 0 ? .memory : .cpu)
        table.reloadData()
        if let previous, let row = rows.firstIndex(where: { $0.id == previous }) { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        if let m = value.system.memory {
            summary.stringValue = "内存 \(MetricFormat.gib(m.usedBytes)) / \(MetricFormat.gib(m.totalBytes)) · 压力\(m.pressure) · 压缩 \(MetricFormat.gib(m.compressedBytes)) · 交换 \(m.swapUsedBytes.map(MetricFormat.gib) ?? "—")"
        } else { summary.stringValue = "系统内存读数不可用" }
        advice.stringValue = value.advice.prefix(2).joined(separator: "\n")
        if !value.errors.isEmpty { status.stringValue = value.errors.joined(separator: "；") }
        else if status.stringValue.isEmpty || status.stringValue.hasPrefix("正在") {
            let clock = DateFormatter(); clock.dateFormat = "HH:mm:ss"
            status.stringValue = "\(clock.string(from: value.sampledAt)) · 读取 \(value.groups.flatMap(\.processes).count) 个进程，\(value.unreadableIdentityCount) 个身份不可读 · 用时 \(String(format: "%.1f", value.sampleSeconds)) 秒"
        }
        updateSelection()
    }
    private func setBusy(_ value: Bool) {
        busy = value; refreshButton.isEnabled = !value; sortControl.isEnabled = !value; updateSelection()
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
    @objc private func quitSelected() { confirm(action: "quit") }
    @objc private func restartSelected() { confirm(action: "restart") }
    private func confirm(action: String) {
        guard !busy, let member = selectedGroup?.processes.first, let window = view.window else { return }
        do {
            let plan = try ResourceActions.prepare(pid: member.identity.pid, token: member.token, action: action)
            let alert = NSAlert(); alert.messageText = "\(action == "restart" ? "重启" : "正常退出") \(plan.name)？"
            alert.informativeText = plan.warning
            alert.addButton(withTitle: action == "restart" ? "重启并复查" : "正常退出"); alert.addButton(withTitle: "取消")
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn, let self else { return }
                self.setBusy(true); self.status.stringValue = "正在\(action == "restart" ? "重启" : "退出")并复查…"
                self.work.async {
                    let result = ResourceActions.perform(pid: member.identity.pid, token: member.token, action: action, dryRun: false)
                    let fresh = ResourceDiagnostics.collect()
                    DispatchQueue.main.async {
                        self.setBusy(false); self.apply(fresh); self.status.stringValue = result.message
                    }
                }
            }
        } catch { status.stringValue = (error as? ResourceActionError)?.message ?? error.localizedDescription }
    }
}

final class DiagnosticWindowController: NSWindowController, NSWindowDelegate {
    let diagnosticView = DiagnosticViewController()
    var didClose: (() -> Void)?
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "LiteGauge · 资源诊断"; window.minSize = NSSize(width: 660, height: 600)
        window.contentViewController = diagnosticView; window.delegate = self; window.isReleasedWhenClosed = false
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); diagnosticView.refresh() }
    func windowWillClose(_ notification: Notification) { didClose?() }
}
