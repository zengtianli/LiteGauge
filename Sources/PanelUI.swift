import AppKit

private enum PanelKeyboard {
    static func handle(_ event: NSEvent, view: NSView) -> Bool {
        if event.keyCode == 53 {
            var ancestor: NSView? = view
            while let current = ancestor {
                if let panel = current as? GaugePanelView { panel.dismiss?(); return true }
                ancestor = current.superview
            }
        }
        if event.keyCode == 125 || event.keyCode == 126 {
            view.window?.makeFirstResponder(event.keyCode == 125 ? view.nextKeyView : view.previousKeyView)
            return true
        }
        return false
    }
}

final class PanelActionButton: NSButton {
    var prominent = false { didSet { needsDisplay = true } }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard prominent else { super.draw(dirtyRect); return }
        let fill: NSColor = isEnabled ? (isHighlighted ? NSColor.controlAccentColor.blended(withFraction: 0.15, of: .black)! : .controlAccentColor) : .quaternaryLabelColor
        fill.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: isEnabled ? NSColor.white : NSColor.secondaryLabelColor]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
            ring.lineWidth = 1; ring.stroke()
        }
    }
    override func keyDown(with event: NSEvent) {
        if !PanelKeyboard.handle(event, view: self) { super.keyDown(with: event) }
    }
}

final class PanelBudgetSwitch: NSSwitch {
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if !PanelKeyboard.handle(event, view: self) { super.keyDown(with: event) }
    }
}

/// The whole production popover content: one material, one view tree, all original operations.
final class GaugePanelView: NSVisualEffectView {
    static let size = NSSize(width: 360, height: 650)
    let resources = SummaryView(frame: NSRect(x: 20, y: 250, width: 320, height: 145))
    let sessions = SessionSummaryRow(frame: NSRect(x: 20, y: 60, width: 320, height: 166))
    let budgetSwitch = PanelBudgetSwitch(frame: NSRect(x: 304, y: 454, width: 36, height: 22))
    private let careStatus = NSTextField(wrappingLabelWithString: "超预算自动处理已关闭")
    private(set) var buttons: [String: PanelActionButton] = [:]
    var dismiss: (() -> Void)?
    var snapshot: MetricsSnapshot? { resources.snapshot }
    var careText: String { careStatus.stringValue }
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: NSRect(origin: frame.origin, size: Self.size))
        material = .popover; blendingMode = .withinWindow; state = .active
        wantsLayer = true; layer?.cornerRadius = 12; layer?.masksToBounds = true
        setAccessibilityElement(false)
        let icon = NSImageView(frame: NSRect(x: 20, y: 16, width: 30, height: 30))
        icon.image = Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: nil)
        icon.imageScaling = .scaleProportionallyDown; icon.contentTintColor = .controlAccentColor
        addSubview(icon)
        label("轻仪", frame: NSRect(x: 60, y: 14, width: 200, height: 20), size: 15, weight: .semibold)
        label("LiteGauge", frame: NSRect(x: 60, y: 34, width: 200, height: 15), size: 10, color: .secondaryLabelColor)
        let refresh = action("立即刷新", y: 15, frame: NSRect(x: 308, y: 15, width: 32, height: 30))
        refresh.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "立即刷新")
        refresh.imagePosition = .imageOnly; refresh.toolTip = "立即刷新（⌘R）"
        addSubview(sessions)
        separator(238); addSubview(resources); separator(407)
        action("资源建议与自动处理…", y: 420)
        label("内存超预算时自动处理", frame: NSRect(x: 20, y: 455, width: 270, height: 20), size: 12)
        budgetSwitch.setAccessibilityLabel("内存超预算时自动处理")
        addSubview(budgetSwitch)
        careStatus.frame = NSRect(x: 20, y: 478, width: 320, height: 26)
        careStatus.font = .systemFont(ofSize: 10); careStatus.textColor = .secondaryLabelColor
        careStatus.maximumNumberOfLines = 2; addSubview(careStatus)
        action("打开活动监视器…", y: 508)
        action("设置…", y: 536)
        action("检查更新…", y: 564)
        separator(598)
        let footer = action("刷新", y: 612, frame: NSRect(x: 20, y: 612, width: 160, height: 24))
        footer.title = "⌘R 刷新"; footer.font = .systemFont(ofSize: 11); footer.contentTintColor = .secondaryLabelColor
        let quit = action("退出轻仪", y: 612, frame: NSRect(x: 226, y: 612, width: 114, height: 24))
        quit.title = "退出轻仪  ⌘Q"; quit.alignment = .right; quit.font = .systemFont(ofSize: 11)
        quit.contentTintColor = .secondaryLabelColor
        rebuildKeyLoop()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
        let label = NSTextField(labelWithString: text); label.frame = frame
        label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
        addSubview(label)
    }
    private func separator(_ y: CGFloat) {
        let line = NSBox(frame: NSRect(x: 20, y: y, width: 320, height: 1)); line.boxType = .separator
        addSubview(line)
    }
    @discardableResult private func action(_ title: String, y: CGFloat, frame: NSRect? = nil) -> PanelActionButton {
        let button = PanelActionButton(title: title, target: nil, action: nil)
        button.frame = frame ?? NSRect(x: 16, y: y, width: 328, height: 24)
        button.font = .systemFont(ofSize: 12); button.isBordered = false; button.alignment = .left
        // Borderless AppKit controls otherwise use inactive-window text in never-key snapshot windows.
        button.contentTintColor = .labelColor
        button.setAccessibilityLabel(title); buttons[title] = button; addSubview(button)
        return button
    }
    func wire(_ items: [NSMenuItem]) {
        for item in items {
            guard let action = item.action, let button = buttons[item.title] else { continue }
            button.target = item.target; button.action = action
            button.keyEquivalent = item.keyEquivalent; button.keyEquivalentModifierMask = item.keyEquivalentModifierMask
        }
        if let refresh = buttons["立即刷新"], let footer = buttons["刷新"] { footer.target = refresh.target; footer.action = refresh.action }
        if let automatic = items.first(where: { $0.title == "内存超预算时自动处理" }) {
            budgetSwitch.target = automatic.target; budgetSwitch.action = automatic.action
            setCare(text: careText, enabled: automatic.state == .on)
        }
        rebuildKeyLoop()
    }
    var keyControls: [NSView] {
        let controls: [NSView?] = [buttons["立即刷新"], sessions.button, buttons["资源建议与自动处理…"], budgetSwitch,
         buttons["打开活动监视器…"], buttons["设置…"], buttons["检查更新…"], buttons["刷新"], buttons["退出轻仪"]]
        return controls.compactMap { $0 }
    }
    private func rebuildKeyLoop() {
        let controls = keyControls
        for (index, control) in controls.enumerated() { control.nextKeyView = controls[(index + 1) % controls.count] }
    }
    func update(_ snapshot: MetricsSnapshot) {
        resources.update(snapshot)
        setAccessibilityLabel("轻仪资源与会话摘要")
    }
    func updateSessions() { sessions.update(SessionSummary.read()) }
    func setCare(text: String, enabled: Bool) {
        careStatus.stringValue = text; careStatus.toolTip = text
        budgetSwitch.state = enabled ? .on : .off
    }
    override func cancelOperation(_ sender: Any?) { dismiss?() }
}

enum PanelSnapshotRenderer {
    /// Attach the *entire production content* to a never-ordered AppKit window so material and controls resolve together.
    static func bitmap(_ panel: GaugePanelView, appearance: NSAppearance.Name) -> NSBitmapImageRep {
        let window = NSWindow(contentRect: panel.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = .windowBackgroundColor
        panel.appearance = window.appearance; window.contentView = panel
        panel.layoutSubtreeIfNeeded(); window.displayIfNeeded()
        let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds)!
        panel.appearance?.performAsCurrentDrawingAppearance { panel.cacheDisplay(in: panel.bounds, to: bitmap) }
        window.contentView = nil
        return bitmap
    }
    static func save(_ panel: GaugePanelView, to url: URL, appearance: NSAppearance.Name = .aqua) throws {
        let bitmap = self.bitmap(panel, appearance: appearance)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "LiteGauge.Panel", code: 1) }
        try png.write(to: url)
    }
}
