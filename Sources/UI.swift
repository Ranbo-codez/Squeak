import AppKit
import ServiceManagement
import ObjectiveC

final class FlippedView: NSView { override var isFlipped: Bool { true } }
final class FlippedClip: NSClipView { override var isFlipped: Bool { true } }

final class ClosureSlider: NSSlider {
    var handler: ((Double) -> Void)?
    convenience init(min: Double, max: Double, value: Double, _ h: @escaping (Double) -> Void) {
        self.init(value: value, minValue: min, maxValue: max, target: nil, action: nil)
        handler = h; target = self; action = #selector(fire); isContinuous = true
    }
    @objc func fire() { handler?(doubleValue) }
}

final class ClosureButton: NSButton {
    var handler: (() -> Void)?
    convenience init(title: String, _ h: @escaping () -> Void) {
        self.init(title: title, target: nil, action: nil)
        handler = h; target = self; action = #selector(fire)
    }
    @objc func fire() { handler?() }
}

final class ClosureMenuItem: NSMenuItem {
    private var handler: () -> Void
    init(title: String, _ h: @escaping () -> Void) { handler = h; super.init(title: title, action: #selector(fire), keyEquivalent: ""); target = self }
    required init(coder: NSCoder) { fatalError() }
    @objc func fire() { handler() }
}

final class Card: NSView {
    var onClick: (() -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; layer?.cornerRadius = 14 }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { updateLayer() }
    override func updateLayer() { layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor }
    override func mouseDown(with e: NSEvent) { onClick?() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

func label(_ s: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let t = NSTextField(labelWithString: s)
    t.font = .systemFont(ofSize: size, weight: weight); t.textColor = color
    t.lineBreakMode = .byTruncatingTail
    if size <= 11 { t.lineBreakMode = .byWordWrapping; t.maximumNumberOfLines = 0; t.preferredMaxLayoutWidth = 328 }
    t.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return t
}

func pct(_ v: Double) -> String { "\(Int((v / 3 * 100).rounded()))%" }

func imageView(_ img: NSImage, _ side: CGFloat) -> NSImageView {
    let v = NSImageView(image: img)
    v.translatesAutoresizingMaskIntoConstraints = false
    v.widthAnchor.constraint(equalToConstant: side).isActive = true
    v.heightAnchor.constraint(equalToConstant: side).isActive = true
    return v
}

func hstack(_ views: [NSView], spacing: CGFloat = 10, align: NSLayoutConstraint.Attribute = .centerY) -> NSStackView {
    let s = NSStackView(views: views); s.orientation = .horizontal; s.spacing = spacing; s.alignment = align
    return s
}

final class PanelVC: NSViewController {
    static let width: CGFloat = 360
    var selected: String?
    private let stack = NSStackView()
    private let scroll = NSScrollView()

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: Self.width, height: 520))
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.contentView = FlippedClip(); scroll.contentView.drawsBackground = false
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -16),
        ])
        root.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                                     scroll.topAnchor.constraint(equalTo: root.topAnchor), scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor)])
        view = root
        render()
    }

    func add(_ v: NSView, fill: Bool = true) {
        stack.addArrangedSubview(v)
        if fill { v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    }

    func render() {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let e = Engine.shared
        if let id = selected, let d = e.connected.first(where: { $0.id == id }) { renderDetail(d) } else { selected = nil; renderList() }
        view.layoutSubtreeIfNeeded()
        preferredContentSize = NSSize(width: Self.width, height: min(540, max(240, stack.fittingSize.height + 32)))
        scroll.documentView?.scroll(.zero)
    }

    // MARK: list
    func renderList() {
        let e = Engine.shared
        let title = label("Squeak", size: 22, weight: .bold)
        let sub = label(e.connected.isEmpty ? "No pointing devices found" : "\(e.connected.count) input device\(e.connected.count == 1 ? "" : "s") connected", size: 12, color: .secondaryLabelColor)
        add(title); add(sub)
        for d in e.connected {
            let s = e.settings(for: d)
            let multi = d.kind == .trackpad && e.connected.filter { $0.kind == .trackpad }.count > 1
            let isActive = e.activeDevice(d.kind)?.id == d.id
            let name = label(d.name, size: 14, weight: .semibold)
            let model = label([d.spec.category == "Generic" ? d.spec.name : "\(d.spec.brand) \(d.spec.name)", d.transport].filter { !$0.isEmpty }.joined(separator: " · "), size: 11.5, color: .secondaryLabelColor)
            let relName = s.base.relTo.flatMap { r in e.connected.first { $0.id == r }?.name } ?? "another device"
            let state = label(s.managed ? (s.base.relTo != nil ? String(format: "%g× ", s.base.factor ?? 1) + relName + (s.base.flat ? " · flat" : "") : "Speed \(s.base.flat ? "flat" : pct(s.base.speed))\(s.base.mult != 1 && HID.supportsScale(d) ? String(format: " · %.2g×", s.base.mult) : "")") + (s.apps.isEmpty ? "" : " · \(s.apps.count) app rule\(s.apps.count == 1 ? "" : "s")") : "Using system settings", size: 11.5, color: s.managed ? .controlAccentColor : .tertiaryLabelColor)
            if multi && isActive { state.stringValue = "Active · " + state.stringValue; state.textColor = .controlAccentColor }
            let texts = NSStackView(views: [name, model, state]); texts.orientation = .vertical; texts.alignment = .leading; texts.spacing = 2
            let row: [NSView] = [imageView(IconArt.image(for: d.spec, size: 64), 64), texts]
            let h = hstack(row, spacing: 12)
            h.translatesAutoresizingMaskIntoConstraints = false
            let card = Card(frame: .zero)
            card.addSubview(h)
            NSLayoutConstraint.activate([
                h.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10), h.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -10),
                h.topAnchor.constraint(equalTo: card.topAnchor, constant: 10), h.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            ])
            card.onClick = { [weak self] in self?.selected = d.id; self?.render() }
            add(card)
        }
        if e.connected.isEmpty { add(label("Plug in or pair a mouse or trackpad and it will show up here.", size: 12, color: .secondaryLabelColor)) }
        if e.connected.filter({ $0.kind == .trackpad }).count > 1 {
            add(label("Trackpads share one macOS setting, so Squeak applies the active trackpad's profile. Every mouse gets its own.", size: 11, color: .tertiaryLabelColor))
        }
        footer()
    }

    func footer() {
        let login = NSButton(checkboxWithTitle: "Open at login", target: self, action: #selector(toggleLogin(_:)))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let quit = ClosureButton(title: "Quit") { NSApp.terminate(nil) }
        quit.bezelStyle = .rounded
        let sp = NSView(); sp.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bar = hstack([login, sp, quit])
        add(bar)
    }

    @objc func toggleLogin(_ b: NSButton) {
        do { if b.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { b.state = SMAppService.mainApp.status == .enabled ? .on : .off; NSSound.beep() }
    }

    // MARK: detail
    func renderDetail(_ d: PointerDevice) {
        let e = Engine.shared
        let back = ClosureButton(title: "‹ Devices") { [weak self] in self?.selected = nil; self?.render() }
        back.isBordered = false; back.contentTintColor = .controlAccentColor
        add(back, fill: false)
        let name = label(d.name, size: 18, weight: .bold)
        let model = label([d.spec.category == "Generic" ? d.spec.name : "\(d.spec.brand) \(d.spec.name)", d.transport].filter { !$0.isEmpty }.joined(separator: " · "), size: 12, color: .secondaryLabelColor)
        let t = NSStackView(views: [name, model]); t.orientation = .vertical; t.alignment = .leading; t.spacing = 3
        add(hstack([imageView(IconArt.image(for: d.spec, size: 88), 88), t], spacing: 14))
        if d.kind == .mouse { autoMatchBlock(d) }

        if d.kind == .trackpad && e.connected.filter({ $0.kind == .trackpad }).count > 1 {
            let on = e.activeDevice(d.kind)?.id == d.id
            let b = ClosureButton(title: on ? "✓ Active device" : "Use this device") { [weak self] in e.makeActive(d); self?.render() }
            b.isEnabled = !on; add(b, fill: false)
        }

        let s = e.settings(for: d)
        let canScale = d.kind == .mouse && HID.supportsScale(d)
        add(label("Pointer speed", size: 13, weight: .semibold))
        add(profileEditor(s.base, device: d, scale: canScale, hint: "Absolute sets a fixed speed. Relative copies another device's speed × a number you choose. Used everywhere unless an app rule overrides it.") { p in e.update(d) { $0.base = p } })

        add(label("App rules", size: 13, weight: .semibold))
        add(label("Different speed while a specific app is in front — e.g. a slower mouse in your game.", size: 11, color: .secondaryLabelColor))
        for (bid, rule) in s.apps.sorted(by: { $0.value.name < $1.value.name }) {
            let icon = NSWorkspace.shared.icon(forFile: rule.path); icon.size = NSSize(width: 24, height: 24)
            let rm = ClosureButton(title: "✕") { [weak self] in e.update(d) { $0.apps[bid] = nil }; self?.render() }
            rm.isBordered = false; rm.contentTintColor = .tertiaryLabelColor
            let sp = NSView(); sp.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let head = hstack([imageView(icon, 24), label(rule.name, weight: .medium), sp, rm])
            let card = Card(frame: .zero)
            let inner = NSStackView(views: [head, profileEditor(rule.profile, device: d, scale: canScale, hint: nil) { p in e.update(d) { $0.apps[bid]?.profile.speed = p.speed; $0.apps[bid]?.profile.flat = p.flat; $0.apps[bid]?.profile.scale = p.scale; $0.apps[bid]?.profile.relTo = p.relTo; $0.apps[bid]?.profile.factor = p.factor } }, gameEditor(rule.profile.game, appName: rule.name, device: d, bundle: bid) { g in e.update(d) { $0.apps[bid]?.profile.game = g } }])
            inner.orientation = .vertical; inner.alignment = .leading; inner.spacing = 6; inner.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10), inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
                inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 8), inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
                head.widthAnchor.constraint(equalTo: inner.widthAnchor), inner.arrangedSubviews[1].widthAnchor.constraint(equalTo: inner.widthAnchor), inner.arrangedSubviews[2].widthAnchor.constraint(equalTo: inner.widthAnchor),
            ])
            add(card)
        }
        let addBtn = ClosureButton(title: "＋ Add app…") { [weak self] in self?.addAppMenu(d, from: nil) }
        addBtn.handler = { [weak self, weak addBtn] in self?.addAppMenu(d, from: addBtn) }
        add(addBtn, fill: false)

        if s.managed {
            let r = ClosureButton(title: "Reset to system settings") { [weak self] in e.reset(d); self?.render() }
            r.bezelStyle = .inline; add(r, fill: false)
        }
        footer()
    }

    func profileEditor(_ p: Profile, device d: PointerDevice, scale: Bool, hint: String?, _ change: @escaping (Profile) -> Void) -> NSView {
        var cur = p
        let e = Engine.shared
        let others = e.connected.filter { $0.id != d.id }
        var rows: [NSView] = []

        let mode = NSSegmentedControl(labels: ["Absolute", "Relative"], trackingMode: .selectOne, target: nil, action: nil)
        mode.selectedSegment = p.relTo == nil ? 0 : 1
        mode.setEnabled(!others.isEmpty, forSegment: 1)
        if others.isEmpty { mode.setToolTip("Connect another device to set speed relative to it.", forSegment: 1) }
        let modeBtn = ClosureButton(title: "") { }  // carrier for the closure
        modeBtn.handler = { [weak self, weak mode] in
            guard let m = mode else { return }
            if m.selectedSegment == 1 {
                cur.relTo = (others.first { $0.kind == .trackpad } ?? others.first)?.id
                cur.factor = cur.factor ?? 1
            } else { cur.relTo = nil }
            change(cur); self?.render()
        }
        mode.target = modeBtn; mode.action = #selector(ClosureButton.fire)
        objc_setAssociatedObject(mode, "h", modeBtn, .OBJC_ASSOCIATION_RETAIN)

        let flat = ClosureButton(title: "Flat") { }
        flat.setButtonType(.switch); flat.state = p.flat ? .on : .off
        flat.toolTip = "Turn off pointer acceleration: movement is 1:1 with the mouse, like raw input."
        let sp = NSView(); sp.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let top = hstack([mode, sp, flat], spacing: 6)
        rows.append(top)

        if let refID = p.relTo {
            // Relative: reference device + any multiplier.
            let pop = NSPopUpButton(frame: .zero, pullsDown: false)
            for o in others { pop.addItem(withTitle: o.name); pop.lastItem?.representedObject = o.id
                let ic = IconArt.image(for: o.spec, size: 16); pop.lastItem?.image = ic }
            if let i = others.firstIndex(where: { $0.id == refID }) { pop.selectItem(at: i) }
            else { pop.addItem(withTitle: "(disconnected device)"); pop.selectItem(at: pop.numberOfItems - 1) }
            let popBtn = ClosureButton(title: "") { }
            popBtn.handler = { [weak pop] in
                guard let id = pop?.selectedItem?.representedObject as? String else { return }
                cur.relTo = id; change(cur)
            }
            pop.target = popBtn; pop.action = #selector(ClosureButton.fire)
            objc_setAssociatedObject(pop, "h", popBtn, .OBJC_ASSOCIATION_RETAIN)
            pop.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rows.append(hstack([label("Relative to", size: 11.5, color: .secondaryLabelColor), pop], spacing: 8))

            let result = label("", size: 11.5, weight: .medium, color: .controlAccentColor)
            let field = NSTextField(string: "")
            field.alignment = .center; field.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            field.widthAnchor.constraint(equalToConstant: 64).isActive = true
            let slider = ClosureSlider(min: -1, max: 1, value: 0) { _ in }   // log10: 0.1× … 10×
            slider.setContentHuggingPriority(.defaultLow, for: .horizontal)

            func fmt(_ f: Double) -> String { f >= 10 ? String(format: "%.0f", f) : (f >= 1 ? String(format: "%.2g", f) : String(format: "%.2g", f)) }
            func refresh(_ f: Double, fromSlider: Bool = false) {
                if !fromSlider { slider.doubleValue = max(-1, min(1, log10(f))) }
                field.stringValue = fmt(f)
                let r = e.resolve(cur, canScale: scale)
                var t = "= \(pct(r.speed)) speed"
                if r.mult != 1 { t += String(format: " · %.2f× sensitivity", r.mult) }
                if r.clamped { t += " · maxed (no sensitivity control on this mouse)" }
                result.stringValue = t
                result.textColor = r.clamped ? .systemOrange : .controlAccentColor
            }
            func setFactor(_ f: Double, fromSlider: Bool = false) {
                let v = max(0.01, min(100, f))
                cur.factor = v; refresh(v, fromSlider: fromSlider); change(cur)
            }
            slider.handler = { v in setFactor((pow(10, v) * 100).rounded() / 100, fromSlider: true) }
            let fieldBtn = ClosureButton(title: "") { }
            fieldBtn.handler = { [weak field] in
                let txt = (field?.stringValue ?? "").replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "×", with: "").replacingOccurrences(of: "x", with: "")
                if let f = Double(txt.trimmingCharacters(in: .whitespaces)), f > 0 { setFactor(f) } else { refresh(cur.factor ?? 1) }
            }
            field.target = fieldBtn; field.action = #selector(ClosureButton.fire)
            objc_setAssociatedObject(field, "h", fieldBtn, .OBJC_ASSOCIATION_RETAIN)
            func step(_ up: Bool) {
                let f = cur.factor ?? 1
                let s = f < 1 ? 0.05 : (f < 4 ? 0.25 : 1)
                setFactor(((up ? f + s : f - s) / s).rounded() * s)
            }
            let minus = ClosureButton(title: "−") { step(false) }; minus.bezelStyle = .rounded
            let plus = ClosureButton(title: "+") { step(true) }; plus.bezelStyle = .rounded
            rows.append(hstack([label("×", size: 14, weight: .semibold, color: .secondaryLabelColor), minus, field, plus, slider], spacing: 6))
            let presets = [0.1, 0.25, 0.5, 1, 2, 4, 10].map { f in
                let b = ClosureButton(title: fmt(f) + "×") { setFactor(f) }
                b.bezelStyle = .inline; b.font = .systemFont(ofSize: 10.5); return b as NSView
            }
            rows.append(hstack(presets, spacing: 4))
            rows.append(result)
            refresh(cur.factor ?? 1)
            flat.handler = { [weak flat] in cur.flat = flat?.state == .on; change(cur) }
        } else {
            let val = label(pct(p.speed), size: 12, weight: .medium, color: .secondaryLabelColor)
            val.alignment = .right; val.widthAnchor.constraint(equalToConstant: 38).isActive = true
            let slider = ClosureSlider(min: 0, max: 3, value: p.speed) { v in cur.speed = v; val.stringValue = pct(v); change(cur) }
            flat.handler = { [weak flat, weak slider] in cur.flat = flat?.state == .on; slider?.isEnabled = !cur.flat; change(cur) }
            slider.isEnabled = !p.flat
            slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rows.append(hstack([label("Slow", size: 10.5, color: .tertiaryLabelColor), slider, label("Fast", size: 10.5, color: .tertiaryLabelColor), val], spacing: 6))
            if scale {
                let mv = label(String(format: "%.2f×", p.mult), size: 12, weight: .medium, color: .secondaryLabelColor)
                mv.alignment = .right; mv.widthAnchor.constraint(equalToConstant: 46).isActive = true
                let ms = ClosureSlider(min: -2, max: 2, value: log2(p.mult)) { v in   // 0.25× … 4×
                    let m = (pow(2, v) * 20).rounded() / 20; cur.scale = m; mv.stringValue = String(format: "%.2f×", m); change(cur)
                }
                ms.setContentHuggingPriority(.defaultLow, for: .horizontal)
                let r2 = hstack([label("Sensitivity", size: 10.5, color: .tertiaryLabelColor), ms, mv], spacing: 6)
                r2.toolTip = "DPI-style multiplier. Keep your mouse's high DPI and turn this down — works with Flat too."
                rows.append(r2)
            }
        }
        let hasHint = hint != nil
        if let hint { rows.append(label(hint, size: 11, color: .secondaryLabelColor)) }
        let v = NSStackView(views: rows)
        v.orientation = .vertical; v.alignment = .leading; v.spacing = 6
        rows.dropLast(hasHint ? 1 : 0).forEach { $0.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true }
        return v
    }

    /// Exact in-game multiplier: scales the movement the app reads (e.g. a game's camera), not the cursor.
    func gameEditor(_ g: Double?, appName: String, device d: PointerDevice, bundle bid: String, _ change: @escaping (Double?) -> Void) -> NSView {
        var rows: [NSView] = []
        let sep = NSBox(); sep.boxType = .separator; rows.append(sep)
        let on = NSButton(checkboxWithTitle: "Exact in-game multiplier", target: nil, action: nil)
        on.state = g == nil ? .off : .on
        on.font = .systemFont(ofSize: 12, weight: .semibold)
        let onBtn = ClosureButton(title: "") { }
        onBtn.handler = { [weak self, weak on] in change(on?.state == .on ? 1 : nil); self?.render() }
        on.target = onBtn; on.action = #selector(ClosureButton.fire)
        objc_setAssociatedObject(on, "h", onBtn, .OBJC_ASSOCIATION_RETAIN)
        rows.append(on)
        if let g {
            rows.append(label("Multiplies the movement \(appName) reads, e.g. camera turning. 0.1 = 10× less movement, as if you'd divided its in-game sensitivity by 10. The cursor itself isn't affected.", size: 11, color: .secondaryLabelColor))
            let field = NSTextField(string: String(format: "%g", g))
            field.alignment = .center; field.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            field.widthAnchor.constraint(equalToConstant: 72).isActive = true
            let fb = ClosureButton(title: "") { }
            fb.handler = { [weak field] in
                let t = (field?.stringValue ?? "").replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "×", with: "").trimmingCharacters(in: .whitespaces)
                if let f = Double(t), f > 0 { let v = max(0.001, min(100, f)); field?.stringValue = String(format: "%g", v); change(v) }
                else { field?.stringValue = String(format: "%g", g) }
            }
            field.target = fb; field.action = #selector(ClosureButton.fire)
            objc_setAssociatedObject(field, "h", fb, .OBJC_ASSOCIATION_RETAIN)
            let presets: [NSView] = [0.05, 0.1, 0.25, 0.5, 2, 4].map { f in
                let b = ClosureButton(title: String(format: "%g×", f)) { [weak field] in field?.stringValue = String(format: "%g", f); change(f) }
                b.bezelStyle = .inline; b.font = .systemFont(ofSize: 10.5); return b
            }
            rows.append(hstack([label("×", size: 14, weight: .semibold, color: .secondaryLabelColor), field] + presets, spacing: 4))
            if !Scaler.ready { rows.append(contentsOf: permissionRows()) }
        }
        let v = NSStackView(views: rows); v.orientation = .vertical; v.alignment = .leading; v.spacing = 6
        sep.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        return v
    }

    /// Guided, one-at-a-time permission setup. The panel re-checks every second while it's open, so no reopening needed.
    func permissionRows() -> [NSView] {
        var rows: [NSView] = []
        rows.append(label("One-time setup", size: 12, weight: .semibold))
        func line(_ done: Bool, _ title: String, _ why: String, action: (() -> Void)?, enabled: Bool, stuckKey: String) {
            let mark = label(done ? "✓" : "○", size: 13, weight: .bold, color: done ? .systemGreen : .tertiaryLabelColor)
            let t = label(title, size: 12, weight: .medium, color: done ? .secondaryLabelColor : .labelColor)
            var row: [NSView] = [mark, t]
            if !done, let action {
                let sp = NSView(); sp.setContentHuggingPriority(.defaultLow, for: .horizontal)
                let b = ClosureButton(title: "Allow…", action); b.bezelStyle = .rounded; b.isEnabled = enabled
                row += [sp, b]
            }
            let h = hstack(row, spacing: 8); rows.append(h)
            h.widthAnchor.constraint(equalToConstant: 300).isActive = true
            if !done && enabled {
                let w = label(why, size: 10.5, color: .tertiaryLabelColor); w.preferredMaxLayoutWidth = 300; rows.append(w)
                if let t0 = Scaler.askedAt[stuckKey], Date().timeIntervalSince(t0) > 8 {
                    let s = label("Switched on but still not ticked? That entry is left over from an older build. Select Squeak in the list, click −, then click Allow… again. (Only needed once — new builds keep the permission.)", size: 10.5, color: .systemOrange)
                    s.preferredMaxLayoutWidth = 300; rows.append(s)
                }
            }
        }
        let ax = Scaler.hasAccessibility, im = Scaler.hasInputMonitoring
        line(ax, "1. Accessibility", "Lets Squeak scale the movement the game reads. Switch Squeak on in the list that opens.",
             action: { Scaler.requestAccessibility() }, enabled: true, stuckKey: "ax")
        line(im, "2. Input Monitoring", "Lets Squeak tell your mouse apart from the trackpad. Switch Squeak on in the list that opens.",
             action: { Scaler.requestInputMonitoring() }, enabled: ax, stuckKey: "im")
        if Scaler.needsRelaunch {
            let b = ClosureButton(title: "Restart Squeak now") { Scaler.relaunch() }
            b.bezelStyle = .rounded; b.keyEquivalent = "\r"; rows.append(b)
            rows.append(label("macOS only applies Input Monitoring after a restart. Squeak reopens by itself.", size: 10.5, color: .tertiaryLabelColor))
        }
        return rows
    }

    private var permTimer: Timer?
    private var lastPerm = (false, false)
    override func viewWillAppear() {
        super.viewWillAppear()
        lastPerm = (Scaler.hasAccessibility, Scaler.hasInputMonitoring)
        permTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = (Scaler.hasAccessibility, Scaler.hasInputMonitoring)
            let stuck = Scaler.askedAt.values.contains { abs($0.timeIntervalSinceNow) > 8 && abs($0.timeIntervalSinceNow) < 10 }
            if now != self.lastPerm || stuck {
                self.lastPerm = now
                if Scaler.needsRelaunch { Scaler.relaunch(); return }   // Input Monitoring just granted: restart automatically
                Engine.shared.reapplyForced()
                self.render()
            }
            if Scaler.ready { self.permTimer?.invalidate(); self.permTimer = nil }
        }
    }
    override func viewWillDisappear() { super.viewWillDisappear(); permTimer?.invalidate(); permTimer = nil }

    /// Pick the game to calibrate: running apps first, or browse for one.
    func gameMenu(_ d: PointerDevice, from: NSView?, _ start: @escaping (String, String, String) -> Void) {
        let menu = NSMenu()
        let head = NSMenuItem(title: "Open your game first, then pick it:", action: nil, keyEquivalent: ""); head.isEnabled = false
        menu.addItem(head)
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        for a in apps {
            let item = ClosureMenuItem(title: a.localizedName ?? a.bundleIdentifier!) { start(a.bundleIdentifier!, a.localizedName ?? "your game", a.bundleURL?.path ?? "") }
            let ic = a.icon ?? NSImage(); ic.size = NSSize(width: 16, height: 16); item.image = ic
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Choose app…") {
            let p = NSOpenPanel(); p.allowedContentTypes = [.application]; p.directoryURL = URL(fileURLWithPath: "/Applications")
            (NSApp.delegate as? AppDelegate)?.popover.behavior = .applicationDefined
            p.begin { r in
                (NSApp.delegate as? AppDelegate)?.popover.behavior = .transient
                guard r == .OK, let url = p.url, let bid = Bundle(url: url)?.bundleIdentifier else { return }
                start(bid, FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), url.path)
            }
        })
        let v = from ?? view
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: v.bounds.height), in: v)
    }

    /// Prominent Auto-match entry at the top of a mouse's page. Creates the game rule if needed.
    func autoMatchBlock(_ d: PointerDevice) {
        let sc = Scaler.shared, e = Engine.shared
        let card = Card(frame: .zero)
        var rows: [NSView] = []
        if sc.calibrating, sc.calDevice == d.id, let bid = sc.calBundle {
            let name = e.settings(for: d).apps[bid]?.name ?? "your game"
            rows = matchSection(appName: name, device: d, bundle: bid) { g in e.update(d) { $0.apps[bid]?.profile.game = g } }
        } else {
            rows.append(label("🎮 Calibrate game sensitivity", size: 13, weight: .bold))
            rows.append(label("Turn one camera circle at the in-game sensitivity that feels right (e.g. 0.015), then one at the value you want to keep (e.g. 0.15). Squeak works out the multiplier that makes them feel the same.", size: 11, color: .secondaryLabelColor))
            let start: (String, String, String) -> Void = { [weak self] bid, name, path in
                e.update(d) { s in
                    if s.apps[bid] == nil { s.apps[bid] = AppRule(name: name, path: path, profile: s.base) }
                    if s.apps[bid]?.profile.game == nil { s.apps[bid]?.profile.game = 1 }
                }
                sc.beginCalibration(bundle: bid, device: d.id, key: e.scalerKey(d)); e.updateScaler(); self?.render()
            }
            var btns: [NSView] = []
            // games this mouse already has a multiplier for get a one-click button
            for (bid, r) in e.settings(for: d).apps.sorted(by: { $0.value.name < $1.value.name }) where r.profile.game != nil {
                let b = ClosureButton(title: "✨ Calibrate in \(r.name)") { start(bid, r.name, r.path) }
                b.bezelStyle = .rounded; b.controlSize = .large; btns.append(b)
            }
            let pick = ClosureButton(title: btns.isEmpty ? "✨ Calibrate in your game…" : "Another game…") { }
            pick.handler = { [weak self, weak pick] in self?.gameMenu(d, from: pick, start) }
            pick.bezelStyle = .rounded; pick.controlSize = btns.isEmpty ? .large : .regular
            btns.append(pick)
            if Scaler.ready { rows.append(contentsOf: btns) } else { rows.append(contentsOf: permissionRows()) }
        }
        let v = NSStackView(views: rows); v.orientation = .vertical; v.alignment = .leading; v.spacing = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12), v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 10), v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
        add(card)
    }

    /// Calibration against the mouse itself: circle 1 at the target in-game sensitivity (no scaling), circle 2 at the
    /// sensitivity you'll keep with the current multiplier on. If circle 2 needed less hand movement, the multiplier is
    /// still too high, so it's corrected by the ratio: f_new = f0 × raw2 / raw1. Repeat to fine-tune.
    func matchSection(appName: String, device d: PointerDevice, bundle bid: String, _ change: @escaping (Double?) -> Void) -> [NSView] {
        let sc = Scaler.shared, e = Engine.shared
        var rows: [NSView] = []
        let r1 = abs(sc.calRaw[0]), r2 = abs(sc.calRaw[1])
        let minCount = 40.0
        rows.append(label("🎯 Calibrating in \(appName)", size: 13, weight: .bold, color: .controlAccentColor))
        func step(_ n: String, _ text: String, _ state: String, _ color: NSColor) {
            let t = label("\(n)  \(text)", size: 11, color: .labelColor); t.preferredMaxLayoutWidth = 300
            let s = label(state, size: 11, weight: .medium, color: color)
            let v = NSStackView(views: [t, s]); v.orientation = .vertical; v.alignment = .leading; v.spacing = 1
            rows.append(v)
        }
        let cur = e.settings(for: d).apps[bid]?.profile.game ?? 1
        var btns: [NSView] = []
        switch sc.calPhase {
        case 1:
            step("1.", "In \(appName), set camera sensitivity to the value that already feels right with this mouse (e.g. 0.015). Pick a landmark, turn one full circle to the right, then come back here.",
                 r1 < minCount ? "Waiting for your circle…" : String(format: "Recorded ✓ (%.0f)", r1), r1 < minCount ? .systemOrange : .systemGreen)
            if r1 >= minCount {
                let next = ClosureButton(title: String(format: "Next: check ×%g", cur)) { [weak self] in sc.startCheckCircle(multiplier: cur); self?.render() }
                next.keyEquivalent = "\r"; btns.append(next)
            }
        case 2:
            step("1.", "Target circle", String(format: "Recorded ✓ (%.0f)", r1), .systemGreen)
            step("2.", String(format: "Now set %@'s sensitivity to the value you want to keep (e.g. 0.15). Squeak applies ×%g. Turn one full circle to the same landmark, then come back here.", appName, sc.calF0),
                 r2 < minCount ? "Waiting for your circle…" : String(format: "Recorded ✓ (%.0f)", r2), r2 < minCount ? .systemOrange : .systemGreen)
            if r2 >= minCount {
                let fNew = max(0.001, min(100, (sc.calF0 * r2 / r1 * 1000).rounded() / 1000))
                let off = abs(r2 / r1 - 1) * 100
                rows.append(label(off < 5 ? String(format: "Already matched (%.0f%% off) — ×%g is right.", off, fNew)
                                          : String(format: "Off by %.0f%%. New multiplier: ×%g", off, fNew),
                                  size: 12, weight: .semibold, color: off < 5 ? .systemGreen : .controlAccentColor))
                let use = ClosureButton(title: String(format: "Use ×%g", fNew)) { [weak self] in change(fNew); sc.endCalibration(); e.updateScaler(); self?.render() }
                use.keyEquivalent = "\r"; btns.append(use)
                btns.append(ClosureButton(title: "Use & check again") { [weak self] in change(fNew); sc.startCheckCircle(multiplier: fNew); self?.render() })
            }
        default: break
        }
        if (sc.calPhase == 1 && r1 > 0) || (sc.calPhase == 2 && r2 > 0) {
            btns.append(ClosureButton(title: "Redo circle") { [weak self] in sc.redoPhase(); self?.render() })
        }
        btns.append(ClosureButton(title: "Cancel") { [weak self] in sc.endCalibration(); e.updateScaler(); self?.render() })
        rows.append(hstack(btns, spacing: 6))
        rows.append(label("Only camera turning counts (when \(appName) locks the cursor), so clicking around its menus is ignored. Use just this mouse during the circles.", size: 10.5, color: .tertiaryLabelColor))
        return rows
    }

    func addAppMenu(_ d: PointerDevice, from: NSView?) {
        let menu = NSMenu()
        let existing = Set(Engine.shared.settings(for: d).apps.keys)
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier && !existing.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        for a in apps {
            let item = NSMenuItem(title: a.localizedName ?? a.bundleIdentifier!, action: #selector(pickRunning(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = (d.id, a.bundleIdentifier!, item.title, a.bundleURL?.path ?? "")
            let ic = a.icon ?? NSImage(); ic.size = NSSize(width: 16, height: 16); item.image = ic
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let other = NSMenuItem(title: "Choose app…", action: #selector(chooseApp(_:)), keyEquivalent: ""); other.target = self; other.representedObject = d.id
        menu.addItem(other)
        let v = from ?? view
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: v.bounds.height), in: v)
    }

    func addRule(_ devID: String, _ bid: String, _ name: String, _ path: String) {
        guard let d = Engine.shared.connected.first(where: { $0.id == devID }) else { return }
        let base = Engine.shared.settings(for: d).base
        Engine.shared.update(d) { $0.apps[bid] = AppRule(name: name, path: path, profile: base) }
        render()
    }

    @objc func pickRunning(_ i: NSMenuItem) {
        guard let (id, bid, name, path) = i.representedObject as? (String, String, String, String) else { return }
        addRule(id, bid, name, path)
    }

    @objc func chooseApp(_ i: NSMenuItem) {
        guard let devID = i.representedObject as? String else { return }
        let p = NSOpenPanel(); p.allowedContentTypes = [.application]; p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.canChooseDirectories = false
        // popover is transient; keep it open while the panel is up
        (NSApp.delegate as? AppDelegate)?.popover.behavior = .applicationDefined
        p.begin { [weak self] r in
            (NSApp.delegate as? AppDelegate)?.popover.behavior = .transient
            guard r == .OK, let url = p.url, let b = Bundle(url: url), let bid = b.bundleIdentifier else { return }
            self?.addRule(devID, bid, FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), url.path)
        }
    }
}
