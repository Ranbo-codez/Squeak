import AppKit

/// Developer helpers for README artwork. Never touches real settings: demo mode uses a throwaway data folder
/// and made-up devices, so no one's actual hardware names end up in screenshots.
enum DevTools {
    static func runIfRequested() {
        let a = CommandLine.arguments
        guard a.count > 2, ["--snapshot", "--icon", "--social", "--sheet", "--distinct"].contains(a[1]) else { return }
        _ = NSApplication.shared
        switch a[1] {
        case "--icon": writeIconset(to: a[2])
        case "--social": writePNG(socialPreview(), size: NSSize(width: 1280, height: 640), to: a[2])
        case "--distinct": distinctReport(limit: Int(a[2]) ?? 15)
        case "--sheet":
            let all = Catalog.all, cols = 15, cell: CGFloat = 64
            let rows = (all.count + cols - 1) / cols
            let size = NSSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell)
            writePNG(NSImage(size: size, flipped: false) { _ in
                for (i, s) in all.enumerated() {
                    IconArt.image(for: s, size: cell - 6).draw(in: NSRect(x: CGFloat(i % cols) * cell + 3, y: size.height - cell * CGFloat(i / cols + 1) + 3, width: cell - 6, height: cell - 6))
                }
                return true
            }, size: size, scale: 2, to: a[2])
        default: snapshot(out: a[2], select: a.count > 3 ? a[3] : nil, dark: a.contains("--dark"))
        }
        exit(0)
    }

    /// Renders every catalog icon and compares every pair pixel by pixel, so near-duplicates can't slip through.
    /// Prints the closest pairs (mean absolute RGB difference, 0–255) and fails if any pair is below the threshold.
    static func distinctReport(limit: Int) {
        let all = Catalog.all, n = 64
        func pixels(_ s: MouseSpec) -> [UInt8] {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                       isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: n * 4, bitsPerPixel: 32)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            IconArt.image(for: s, size: CGFloat(n)).draw(in: NSRect(x: 0, y: 0, width: n, height: n))
            NSGraphicsContext.restoreGraphicsState()
            return Array(UnsafeBufferPointer(start: rep.bitmapData!, count: n * n * 4))
        }
        let px = all.map(pixels)
        var pairs: [(Double, Int, Int)] = []
        for i in 0..<all.count { for j in (i + 1)..<all.count {
            var sum = 0
            for k in stride(from: 0, to: px[i].count, by: 4) { for c in 0..<3 { sum += abs(Int(px[i][k + c]) - Int(px[j][k + c])) } }
            pairs.append((Double(sum) / Double(n * n * 3), i, j))
        } }
        pairs.sort { $0.0 < $1.0 }
        print("\(all.count) icons, \(pairs.count) pairs. Closest:")
        for (d, i, j) in pairs.prefix(limit) { print(String(format: "  %6.2f  %@  vs  %@", d, all[i].name, all[j].name)) }
        let threshold = 6.0
        let bad = pairs.filter { $0.0 < threshold }
        print(bad.isEmpty ? "OK: every pair differs by at least \(threshold)" : "FAIL: \(bad.count) pairs under \(threshold)")
        if !bad.isEmpty { exit(1) }
    }

    // MARK: demo data
    static func demoDevices() -> [PointerDevice] {
        func dev(_ name: String, _ kind: Kind, _ transport: String, _ v: Int, _ p: Int, builtIn: Bool = false) -> PointerDevice {
            let spec = Catalog.match(product: name, manufacturer: "", vendor: v, kind: kind, builtIn: builtIn)
            return PointerDevice(id: "\(v):\(p):\(name)", name: name, kind: kind, transport: transport, builtIn: builtIn, spec: spec, product: name, vendor: v, pid: p)
        }
        return [dev("Razer Viper V3 Pro", .mouse, "USB", 0x1532, 1), dev("MX Master 3S", .mouse, "Bluetooth", 0x046D, 2),
                dev("Magic Trackpad", .trackpad, "Bluetooth", 0x4C, 3), dev("MacBook Trackpad", .trackpad, "Built-in", 0, 0, builtIn: true)]
    }

    static func snapshot(out: String, select: String?, dark: Bool) {
        let e = Engine.shared
        if ProcessInfo.processInfo.environment["SQUEAK_DEMO"] != nil {
            e.connected = demoDevices()
            let viper = e.connected[0], mx = e.connected[1]
            let game = AppRule(name: "Your Game", path: "/nonexistent/Your Game.app", profile: Profile(speed: 0.6875, flat: false, game: 0.1))
            e.data = StoreData(devices: [
                viper.id: DeviceSettings(base: Profile(speed: 0.6875, flat: false), managed: true, apps: ["com.example.game": game]),
                mx.id: DeviceSettings(base: Profile(speed: 1.5, flat: false), managed: true, apps: [:]),
            ], active: [:])
        } else {
            let w = DeviceWatcher(); w.start(); e.connected = w.devices
        }
        if ProcessInfo.processInfo.environment["SQUEAK_CAL"] != nil, let d = e.connected.first(where: { $0.kind == .mouse }) {
            Scaler.shared.beginCalibration(bundle: "com.example.game", device: d.id, key: e.scalerKey(d))
        }
        let vc = PanelVC(); _ = vc.view
        if let s = select { vc.selected = e.connected.first { $0.name.contains(s) }?.id; vc.render() }
        vc.view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        vc.view.setFrameSize(vc.preferredContentSize); vc.view.layoutSubtreeIfNeeded(); vc.render()
        vc.view.setFrameSize(vc.preferredContentSize); vc.view.layoutSubtreeIfNeeded()
        // opaque window-like background so dark mode text is legible
        let bg = NSView(frame: vc.view.bounds); bg.wantsLayer = true; bg.appearance = vc.view.appearance
        bg.layer?.backgroundColor = (dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.985, alpha: 1)).cgColor
        bg.layer?.cornerRadius = 14
        bg.addSubview(vc.view)
        let rep = bg.bitmapImageRepForCachingDisplay(in: bg.bounds)!
        bg.cacheDisplay(in: bg.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
    }

    // MARK: icon + social preview
    static func writePNG(_ img: NSImage, size: NSSize, scale: CGFloat = 1, to path: String) {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        img.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    static func writeIconset(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for s in [16, 32, 128, 256, 512] {
            let img = IconArt.appIcon(size: CGFloat(s))
            writePNG(img, size: NSSize(width: s, height: s), to: "\(dir)/icon_\(s)x\(s).png")
            writePNG(img, size: NSSize(width: s, height: s), scale: 2, to: "\(dir)/icon_\(s)x\(s)@2x.png")
        }
    }

    static func socialPreview() -> NSImage {
        NSImage(size: NSSize(width: 1280, height: 640), flipped: false) { r in
            NSGradient(colors: [hex("2b1d4f"), hex("5b2a6e"), hex("b8456d")])!.draw(in: r, angle: -25)
            // faint scattered device icons on the right
            let picks = ["Viper V3 Pro", "MX Master 3S", "Model O", "G Pro X Superlight 2", "MX Vertical", "Magic Trackpad",
                         "Starlight-12", "Ergo M575", "DeathAdder V3 Pro", "Magic Mouse", "Aerox 3", "Lift"]
            let specs = picks.compactMap { n in Catalog.all.first { $0.name == n } }
            for (i, s) in specs.enumerated() {
                let col = i % 4, row = i / 4
                IconArt.image(for: s, size: 112).draw(in: NSRect(x: 760 + CGFloat(col) * 124, y: 430 - CGFloat(row) * 140, width: 112, height: 112))
            }
            IconArt.appIcon(size: 210).draw(in: NSRect(x: 80, y: 340, width: 210, height: 210))
            let title = NSAttributedString(string: "Squeak", attributes: [.font: NSFont.systemFont(ofSize: 104, weight: .heavy), .foregroundColor: NSColor.white])
            title.draw(at: NSPoint(x: 312, y: 384))
            let p = NSMutableParagraphStyle(); p.lineSpacing = 6
            let tag = NSAttributedString(string: "Mouse & trackpad sensitivity for macOS.\nPer device, per app, calibrated to your game.",
                                         attributes: [.font: NSFont.systemFont(ofSize: 31, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(0.95), .paragraphStyle: p])
            tag.draw(in: NSRect(x: 84, y: 160, width: 660, height: 130))
            let foot = NSAttributedString(string: "Menu-bar app · ~18 MB · 0% CPU idle · 106 mouse icons",
                                          attributes: [.font: NSFont.systemFont(ofSize: 24, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.7)])
            foot.draw(at: NSPoint(x: 86, y: 84))
            return true
        }
    }
}
