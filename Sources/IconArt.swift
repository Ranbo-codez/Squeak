import AppKit

/// Procedural "sticker" icons: pastel tile, chunky outline, glossy highlight. Drawn on demand, nothing cached on disk.
enum IconArt {
    static let ink = NSColor(srgbRed: 0.11, green: 0.10, blue: 0.19, alpha: 1)

    static func image(for s: MouseSpec, size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.saveGState()
            ctx.translateBy(x: r.minX, y: r.minY)
            ctx.scaleBy(x: r.width, y: r.height)
            draw(s, ctx)
            ctx.restoreGState()
            return true
        }
    }

    /// The app's own icon: macOS-style squircle, a big glossy cartoon mouse with speed lines and a sensitivity dial.
    static func appIcon(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.saveGState()
            ctx.translateBy(x: r.minX, y: r.minY); ctx.scaleBy(x: r.width, y: r.height)
            // Apple icon grid: ~10% margin, squircle-ish rounded rect
            let tile = NSBezierPath(roundedRect: NSRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), xRadius: 0.18, yRadius: 0.18)
            NSGraphicsContext.saveGraphicsState()
            let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.3); sh.shadowOffset = NSSize(width: 0, height: -0.012); sh.shadowBlurRadius = 0.025; sh.set()
            hex("ff8a5c").setFill(); tile.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGradient(colors: [hex("ffb36b"), hex("ff6f8e"), hex("8a5cff")])!.draw(in: tile, angle: -55)
            ctx.saveGState(); tile.addClip()
            // soft glow behind the mouse
            NSGradient(starting: NSColor.white.withAlphaComponent(0.45), ending: NSColor.white.withAlphaComponent(0))!
                .draw(in: NSBezierPath(ovalIn: NSRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)), relativeCenterPosition: .zero)
            // speed lines on the left
            for (i, y) in [0.62, 0.52, 0.42].enumerated() {
                let l = NSBezierPath(); l.move(to: NSPoint(x: 0.17 + CGFloat(i) * 0.02, y: y)); l.line(to: NSPoint(x: 0.29, y: y))
                l.lineWidth = 0.028; l.lineCapStyle = .round; NSColor.white.withAlphaComponent(0.85).setStroke(); l.stroke()
            }
            sparkle(0.75, 0.76, 0.05); sparkle(0.70, 0.24, 0.03)
            // the mouse, shrunk into the tile
            ctx.saveGState()
            ctx.translateBy(x: 0.53, y: 0.5); ctx.scaleBy(x: 0.74, y: 0.74); ctx.rotate(by: -0.12); ctx.translateBy(x: -0.5, y: -0.5)
            let spec = MouseSpec(brand: "Squeak", name: "Squeak", key: "", shape: .ambi, body: hex("f6f6fb"), accent: hex("ff4f8b"), rgb: false, category: "App")
            gamingMouse(spec, ergo: false, lite: false, logo: false)
            // cute face: it's a mouse after all
            for x in [0.44, 0.56] {
                let eye = NSBezierPath(ovalIn: NSRect(x: x - 0.022, y: 0.40, width: 0.044, height: 0.056)); ink.setFill(); eye.fill()
                let hi = NSBezierPath(ovalIn: NSRect(x: x - 0.008, y: 0.432, width: 0.016, height: 0.016)); NSColor.white.setFill(); hi.fill()
            }
            let smile = NSBezierPath(); smile.move(to: NSPoint(x: 0.47, y: 0.365)); smile.curve(to: NSPoint(x: 0.53, y: 0.365), controlPoint1: NSPoint(x: 0.48, y: 0.335), controlPoint2: NSPoint(x: 0.52, y: 0.335))
            smile.lineWidth = 0.014; smile.lineCapStyle = .round; ink.setStroke(); smile.stroke()
            for x in [0.40, 0.60] { let c = NSBezierPath(ovalIn: NSRect(x: x - 0.025, y: 0.355, width: 0.05, height: 0.03)); hex("ff8fb1").withAlphaComponent(0.8).setFill(); c.fill() }
            ctx.restoreGState()
            ctx.restoreGState()
            ink.withAlphaComponent(0.12).setStroke(); tile.lineWidth = 0.006; tile.stroke()
            ctx.restoreGState()
            return true
        }
    }

    static func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        a.blended(withFraction: t, of: b) ?? a
    }

    // MARK: composition
    static func draw(_ s: MouseSpec, _ ctx: CGContext) {
        let tint = s.p.tile ?? s.accent
        let tile = NSBezierPath(roundedRect: NSRect(x: 0.01, y: 0.01, width: 0.98, height: 0.98), xRadius: 0.22, yRadius: 0.22)
        NSGradient(starting: mix(tint, .white, 0.80), ending: mix(tint, .white, 0.55))!.draw(in: tile, angle: -60)
        ink.withAlphaComponent(0.10).setStroke(); tile.lineWidth = 0.012; tile.stroke()
        sparkle(0.80, 0.82, 0.055); sparkle(0.20, 0.20, 0.035)
        ctx.saveGState()
        tile.addClip()
        switch s.shape {
        case .ambi, .ambiLite: gamingMouse(s, ergo: false, lite: s.shape == .ambiLite)
        case .ergo, .ergoLite: gamingMouse(s, ergo: true, lite: s.shape == .ergoLite)
        case .office: officeMouse(s, compact: false)
        case .compact: officeMouse(s, compact: true)
        case .vert: verticalMouse(s)
        case .ball: trackball(s)
        case .flat: magicMouse(s)
        case .trackpad: trackpad(s)
        case .laptop: laptop(s)
        }
        ctx.restoreGState()
    }

    // MARK: pieces
    static func body(cx: CGFloat, top: CGFloat, bottom: CGFloat, wL: CGFloat, wR: CGFloat, mid: CGFloat = 0.45) -> NSBezierPath {
        let ym = bottom + (top - bottom) * mid
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx, y: top))
        p.curve(to: NSPoint(x: cx + wR, y: ym), controlPoint1: NSPoint(x: cx + wR * 0.78, y: top), controlPoint2: NSPoint(x: cx + wR, y: ym + (top - ym) * 0.62))
        p.curve(to: NSPoint(x: cx, y: bottom), controlPoint1: NSPoint(x: cx + wR, y: ym - (ym - bottom) * 0.62), controlPoint2: NSPoint(x: cx + wR * 0.80, y: bottom))
        p.curve(to: NSPoint(x: cx - wL, y: ym), controlPoint1: NSPoint(x: cx - wL * 0.80, y: bottom), controlPoint2: NSPoint(x: cx - wL, y: ym - (ym - bottom) * 0.62))
        p.curve(to: NSPoint(x: cx, y: top), controlPoint1: NSPoint(x: cx - wL, y: ym + (top - ym) * 0.62), controlPoint2: NSPoint(x: cx - wL * 0.78, y: top))
        p.close()
        return p
    }

    static func shadow(_ p: NSBezierPath) {
        let q = p.copy() as! NSBezierPath
        q.transform(using: AffineTransform(translationByX: 0.014, byY: -0.024))
        ink.withAlphaComponent(0.22).setFill(); q.fill()
    }

    static func paint(_ p: NSBezierPath, _ c: NSColor, lw: CGFloat = 0.034) {
        NSGradient(starting: mix(c, .white, 0.30), ending: mix(c, .black, 0.22))!.draw(in: p, angle: -65)
        outline(p, lw)
    }
    static func outline(_ p: NSBezierPath, _ lw: CGFloat = 0.034) { ink.setStroke(); p.lineWidth = lw; p.lineJoinStyle = .round; p.stroke() }

    static func sparkle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: x, y: y + r))
        p.curve(to: NSPoint(x: x + r, y: y), controlPoint1: NSPoint(x: x, y: y + r * 0.25), controlPoint2: NSPoint(x: x + r * 0.25, y: y))
        p.curve(to: NSPoint(x: x, y: y - r), controlPoint1: NSPoint(x: x + r * 0.25, y: y), controlPoint2: NSPoint(x: x, y: y - r * 0.25))
        p.curve(to: NSPoint(x: x - r, y: y), controlPoint1: NSPoint(x: x, y: y - r * 0.25), controlPoint2: NSPoint(x: x - r * 0.25, y: y))
        p.curve(to: NSPoint(x: x, y: y + r), controlPoint1: NSPoint(x: x - r * 0.25, y: y), controlPoint2: NSPoint(x: x, y: y + r * 0.25))
        NSColor.white.withAlphaComponent(0.9).setFill(); p.fill()
    }

    static func gloss(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat, _ a: CGFloat = 0.55) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: x, y: y0))
        p.curve(to: NSPoint(x: x + 0.01, y: y1), controlPoint1: NSPoint(x: x - 0.025, y: (y0 + y1) / 2), controlPoint2: NSPoint(x: x - 0.02, y: y1 - 0.05))
        p.lineWidth = 0.03; p.lineCapStyle = .round
        NSColor.white.withAlphaComponent(a).setStroke(); p.stroke()
    }

    static func pill(_ r: NSRect, _ c: NSColor, lw: CGFloat = 0.02) {
        let p = NSBezierPath(roundedRect: r, xRadius: min(r.width, r.height) / 2, yRadius: min(r.width, r.height) / 2)
        paint(p, c, lw: lw)
    }

    /// Button split + scroll wheel. Wheel styles: "" plain accent, "wide", "metal" (silver with grooves).
    static func buttons(cx: CGFloat, top: CGFloat, bottom: CGFloat, wL: CGFloat, wR: CGFloat, split: CGFloat, wheel: NSColor, style: String = "", dpi: Bool = false) {
        let yb = top - (top - bottom) * split
        let line = NSBezierPath()
        line.move(to: NSPoint(x: cx - wL * 0.97, y: yb + 0.012))
        line.curve(to: NSPoint(x: cx + wR * 0.97, y: yb + 0.012), controlPoint1: NSPoint(x: cx - wL * 0.4, y: yb - 0.035), controlPoint2: NSPoint(x: cx + wR * 0.4, y: yb - 0.035))
        line.move(to: NSPoint(x: cx, y: top - 0.012)); line.line(to: NSPoint(x: cx, y: yb - 0.012))
        ink.withAlphaComponent(0.85).setStroke(); line.lineWidth = 0.018; line.lineCapStyle = .round; line.stroke()
        let w: CGFloat = style == "wide" ? 0.075 : 0.054
        let r = NSRect(x: cx - w / 2, y: yb + 0.02, width: w, height: 0.115)
        if style == "metal" {
            pill(r, hex("c9ced8"))
            for i in 1...3 { let g = NSBezierPath(); let y = r.minY + r.height * CGFloat(i) / 4
                g.move(to: NSPoint(x: r.minX + 0.012, y: y)); g.line(to: NSPoint(x: r.maxX - 0.012, y: y)); g.lineWidth = 0.008; ink.withAlphaComponent(0.6).setStroke(); g.stroke() }
        } else { pill(r, wheel) }
        if dpi { pill(NSRect(x: cx - 0.02, y: yb - 0.055, width: 0.04, height: 0.04), mix(wheel, .black, 0.25), lw: 0.014) }
    }

    /// Shell cut-outs for lightweight mice: "holes" (round), "hex", "slots", "cut" (angular frame windows).
    static func pattern(_ kind: String, clip: NSBezierPath, cx: CGFloat, y0: CGFloat, y1: CGFloat, w: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        ink.withAlphaComponent(0.78).setFill()
        switch kind {
        case "slots":
            var y = y0
            while y < y1 { for side in [-1.0, 1.0] {
                let r = NSRect(x: cx + CGFloat(side) * 0.04 - (side < 0 ? w : 0), y: y, width: w - 0.04, height: 0.022)
                NSBezierPath(roundedRect: r, xRadius: 0.011, yRadius: 0.011).fill() }
                y += 0.05 }
        case "hex":
            var row = 0, y = y0
            while y < y1 {
                var x = cx - w + (row % 2 == 0 ? 0 : 0.034)
                while x < cx + w { hexagon(x, y, 0.024).fill(); x += 0.068 }
                y += 0.058; row += 1 }
        case "cut":
            for (dx, flip) in [(-1.0, true), (1.0, false)] {
                let p = NSBezierPath(); let bx = cx + CGFloat(dx) * 0.05
                p.move(to: NSPoint(x: bx, y: y1)); p.line(to: NSPoint(x: bx + CGFloat(dx) * w, y: (y0 + y1) / 2)); p.line(to: NSPoint(x: bx, y: y0)); p.close()
                _ = flip; p.fill() }
        default:
            var row = 0, y = y0
            while y < y1 {
                var x = cx - w + (row % 2 == 0 ? 0 : 0.03)
                while x < cx + w { NSBezierPath(ovalIn: NSRect(x: x - 0.016, y: y - 0.016, width: 0.032, height: 0.032)).fill(); x += 0.06 }
                y += 0.052; row += 1 }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    static func hexagon(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        for i in 0..<6 { let a = CGFloat(i) * .pi / 3 + .pi / 6; let pt = NSPoint(x: x + r * cos(a), y: y + r * sin(a)); i == 0 ? p.move(to: pt) : p.line(to: pt) }
        p.close(); return p
    }

    /// Small palm emblem (generic shapes, not brand logos).
    static func glyph(_ kind: String, _ x: CGFloat, _ y: CGFloat, _ c: NSColor) {
        let r: CGFloat = 0.032
        var p = NSBezierPath()
        switch kind {
        case "tri": p.move(to: NSPoint(x: x, y: y + r)); p.line(to: NSPoint(x: x + r, y: y - r * 0.8)); p.line(to: NSPoint(x: x - r, y: y - r * 0.8)); p.close()
        case "ring": p = NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            c.setStroke(); p.lineWidth = 0.016; p.stroke(); return
        case "chev": p.move(to: NSPoint(x: x - r, y: y + r * 0.6)); p.line(to: NSPoint(x: x, y: y - r * 0.6)); p.line(to: NSPoint(x: x + r, y: y + r * 0.6))
            c.setStroke(); p.lineWidth = 0.018; p.lineCapStyle = .round; p.lineJoinStyle = .round; p.stroke(); return
        case "bolt": p.move(to: NSPoint(x: x + r * 0.3, y: y + r)); p.line(to: NSPoint(x: x - r * 0.6, y: y - r * 0.1)); p.line(to: NSPoint(x: x, y: y - r * 0.1))
            p.line(to: NSPoint(x: x - r * 0.3, y: y - r)); p.line(to: NSPoint(x: x + r * 0.6, y: y + r * 0.1)); p.line(to: NSPoint(x: x, y: y + r * 0.1)); p.close()
        case "diamond": p.move(to: NSPoint(x: x, y: y + r)); p.line(to: NSPoint(x: x + r * 0.75, y: y)); p.line(to: NSPoint(x: x, y: y - r)); p.line(to: NSPoint(x: x - r * 0.75, y: y)); p.close()
        case "plus": p.appendRect(NSRect(x: x - r, y: y - 0.008, width: 2 * r, height: 0.016)); p.appendRect(NSRect(x: x - 0.008, y: y - r, width: 0.016, height: 2 * r))
        case "x": let q = NSBezierPath(); q.move(to: NSPoint(x: x - r * 0.8, y: y - r * 0.8)); q.line(to: NSPoint(x: x + r * 0.8, y: y + r * 0.8))
            q.move(to: NSPoint(x: x - r * 0.8, y: y + r * 0.8)); q.line(to: NSPoint(x: x + r * 0.8, y: y - r * 0.8))
            c.setStroke(); q.lineWidth = 0.016; q.lineCapStyle = .round; q.stroke(); return
        case "wave": p.move(to: NSPoint(x: x - r, y: y)); p.curve(to: NSPoint(x: x, y: y), controlPoint1: NSPoint(x: x - r * 0.6, y: y + r), controlPoint2: NSPoint(x: x - r * 0.4, y: y + r))
            p.curve(to: NSPoint(x: x + r, y: y), controlPoint1: NSPoint(x: x + r * 0.4, y: y - r), controlPoint2: NSPoint(x: x + r * 0.6, y: y - r))
            c.setStroke(); p.lineWidth = 0.016; p.lineCapStyle = .round; p.stroke(); return
        case "hex": p = hexagon(x, y, r)
        case "star":
            for i in 0..<10 { let a = CGFloat(i) * .pi / 5 + .pi / 2; let rr = i % 2 == 0 ? r : r * 0.45
                let pt = NSPoint(x: x + rr * cos(a), y: y + rr * sin(a)); i == 0 ? p.move(to: pt) : p.line(to: pt) }
            p.close()
        case "sail": p.move(to: NSPoint(x: x - r, y: y - r * 0.7)); p.line(to: NSPoint(x: x - r * 0.1, y: y + r)); p.line(to: NSPoint(x: x - r * 0.1, y: y - r * 0.7)); p.close()
            p.move(to: NSPoint(x: x + r * 0.1, y: y - r * 0.7)); p.line(to: NSPoint(x: x + r * 0.1, y: y + r * 0.6)); p.line(to: NSPoint(x: x + r, y: y - r * 0.7)); p.close()
        case "none": return
        default: p = NSBezierPath(ovalIn: NSRect(x: x - r * 0.9, y: y - r * 0.9, width: 1.8 * r, height: 1.8 * r))
        }
        c.setFill(); p.fill(); ink.setStroke(); p.lineWidth = 0.01; p.stroke()
    }

    static func glow(cx: CGFloat, bottom: CGFloat, w: CGFloat, color: NSColor) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx - w * 0.62, y: bottom + 0.11))
        p.curve(to: NSPoint(x: cx + w * 0.62, y: bottom + 0.11), controlPoint1: NSPoint(x: cx - w * 0.3, y: bottom + 0.035), controlPoint2: NSPoint(x: cx + w * 0.3, y: bottom + 0.035))
        p.lineWidth = 0.032; p.lineCapStyle = .round
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow(); sh.shadowColor = color.withAlphaComponent(0.9); sh.shadowBlurRadius = 0.03; sh.set()
        color.setStroke(); p.stroke()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.85).setStroke(); p.lineWidth = 0.012; p.stroke()
    }

    static func cable(cx: CGFloat, top: CGFloat) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx, y: top - 0.01))
        p.curve(to: NSPoint(x: cx + 0.07, y: 1.02), controlPoint1: NSPoint(x: cx - 0.06, y: top + 0.05), controlPoint2: NSPoint(x: cx + 0.12, y: top + 0.04))
        p.lineWidth = 0.034; p.lineCapStyle = .round; ink.setStroke(); p.stroke()
        p.lineWidth = 0.014; NSColor(white: 0.45, alpha: 1).setStroke(); p.stroke()
    }

    /// Two-tone side panels, painted inside the body outline.
    static func panels(_ b: NSBezierPath, cx: CGFloat, wL: CGFloat, wR: CGFloat, top: CGFloat, bottom: CGFloat, color: NSColor) {
        NSGraphicsContext.saveGraphicsState(); b.addClip()
        let h = (top - bottom) * 0.62
        NSGradient(starting: mix(color, .white, 0.2), ending: mix(color, .black, 0.2))!.draw(in: NSRect(x: cx - wL - 0.01, y: bottom, width: wL * 0.42, height: h), angle: -90)
        NSGradient(starting: mix(color, .white, 0.2), ending: mix(color, .black, 0.2))!.draw(in: NSRect(x: cx + wR * 0.58, y: bottom, width: wR * 0.45, height: h), angle: -90)
        NSGraphicsContext.restoreGraphicsState()
        outline(b)
    }

    /// Thumb-side buttons: n stacked pills, or a 3×4 MMO grid.
    static func sideButtons(n: Int, grid: Bool, x: CGFloat, yMid: CGFloat, color: NSColor, right: Bool = false) {
        if grid {
            for r in 0..<4 { for c in 0..<3 {
                let rect = NSRect(x: x - 0.06 + CGFloat(c) * 0.046, y: yMid - 0.11 + CGFloat(r) * 0.055, width: 0.04, height: 0.045)
                let p = NSBezierPath(roundedRect: rect, xRadius: 0.008, yRadius: 0.008); color.setFill(); p.fill(); ink.setStroke(); p.lineWidth = 0.012; p.stroke() } }
            return
        }
        guard n > 0 else { return }
        let h: CGFloat = n <= 2 ? 0.06 : (n <= 4 ? 0.045 : 0.032), gap: CGFloat = 0.012
        let total = CGFloat(n) * h + CGFloat(n - 1) * gap
        for i in 0..<n {
            let y = yMid - total / 2 + CGFloat(i) * (h + gap)
            pill(NSRect(x: right ? x - 0.04 : x - 0.03, y: y, width: 0.07, height: h), color, lw: 0.016)
        }
    }

    // MARK: shapes
    static func gamingMouse(_ s: MouseSpec, ergo: Bool, lite: Bool, logo: Bool = true) {
        let p = s.p
        let cx: CGFloat = 0.5, H = 0.37 * p.len
        let top = 0.5 + H, bottom = 0.5 - H
        let wL = (ergo ? 0.185 : 0.19) * p.wid, wR = (ergo ? 0.225 : 0.19) * p.wid
        let mid = p.mid ?? (ergo ? 0.40 : 0.45)
        let b = body(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, mid: mid)
        if p.cable { cable(cx: cx, top: top) }
        shadow(b)
        if ergo || p.wing {   // thumb rest
            let wide: CGFloat = p.wing ? 0.17 : 0.12
            paint(NSBezierPath(ovalIn: NSRect(x: cx - wL - wide / 2, y: 0.5 - H * 0.62, width: wide, height: H * 0.7)), mix(s.body, .black, 0.08))
        }
        if p.paddle {         // clutch / sniper paddle
            let f = NSBezierPath(); f.move(to: NSPoint(x: cx - wL + 0.01, y: 0.58)); f.line(to: NSPoint(x: cx - wL - 0.13, y: 0.50)); f.line(to: NSPoint(x: cx - wL + 0.01, y: 0.42)); f.close()
            paint(f, s.accent, lw: 0.016)
        }
        paint(b, s.body)
        if let pc = p.panel { panels(b, cx: cx, wL: wL, wR: wR, top: top, bottom: bottom, color: pc) }
        if let st = p.stripe {
            NSGraphicsContext.saveGraphicsState(); b.addClip()
            st.setFill(); NSRect(x: cx - 0.022, y: bottom, width: 0.044, height: (top - bottom) * 0.62).fill()
            NSGraphicsContext.restoreGraphicsState(); outline(b)
        }
        let pat = p.pat.isEmpty ? (lite ? "holes" : "") : p.pat
        if !pat.isEmpty { pattern(pat, clip: b, cx: cx, y0: bottom + 0.08, y1: top - (top - bottom) * 0.40, w: wL + 0.02) }
        buttons(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, split: pat.isEmpty ? 0.34 : 0.36, wheel: s.accent, style: p.wheel, dpi: p.dpi)
        if p.sniper { pill(NSRect(x: cx - wL - 0.005, y: top - (top - bottom) * 0.30, width: 0.05, height: 0.04), hex("ff3b3b"), lw: 0.014) }
        sideButtons(n: p.side == 0 && ergo ? 2 : p.side, grid: p.grid, x: cx - wL, yMid: 0.5, color: s.accent)
        sideButtons(n: p.rside, grid: false, x: cx + wR, yMid: 0.5, color: s.accent, right: true)
        if logo {
            if s.rgb { glow(cx: cx, bottom: bottom, w: wL + wR, color: s.accent) }
            if !(pat == "holes" || pat == "hex" || pat == "slots") || s.p.glyph != "" {
                glyph(p.glyph.isEmpty ? "dot" : p.glyph, cx, bottom + (s.rgb ? 0.17 : 0.13), s.accent)
            }
        }
        gloss(cx - wL * 0.62, top - 0.09, 0.50, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
    }

    static func officeMouse(_ s: MouseSpec, compact: Bool) {
        let p = s.p
        let cx: CGFloat = 0.52
        let H = (compact ? 0.29 : 0.355) * p.len
        let top = 0.5 + H, bottom = 0.5 - H
        let wL = (compact ? 0.15 : 0.17) * p.wid, wR = (compact ? 0.17 : 0.22) * p.wid
        let b = body(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, mid: p.mid ?? 0.42)
        if p.cable { cable(cx: cx, top: top) }
        shadow(b)
        if !compact { paint(NSBezierPath(ovalIn: NSRect(x: cx - wL - 0.075, y: 0.5 - H * 0.8, width: 0.15, height: H * 0.85)), mix(s.body, .black, 0.08)) }
        paint(b, s.body)
        if let pc = p.panel { panels(b, cx: cx, wL: wL, wR: wR, top: top, bottom: bottom, color: pc) }
        buttons(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, split: 0.34, wheel: s.accent, style: p.wheel, dpi: p.dpi)
        if !compact && !p.nothumb { pill(NSRect(x: cx - wL - 0.02, y: 0.44, width: 0.045, height: 0.11), s.accent) }
        sideButtons(n: p.side, grid: false, x: cx - wL, yMid: 0.5 - H * 0.15, color: mix(s.body, .white, 0.25))
        glyph(p.glyph.isEmpty ? "dot" : p.glyph, cx, bottom + 0.12, s.accent)
        gloss(cx - wL * 0.6, top - 0.09, 0.50, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
    }

    static func verticalMouse(_ s: MouseSpec) {
        let p = s.p
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: 0.5, y: 0.5); ctx.rotate(by: -0.20 * (p.tilt ?? 1)); ctx.translateBy(x: -0.5, y: -0.5)
        let cx: CGFloat = 0.5, H = 0.39 * p.len
        let top = 0.51 + H, bottom = 0.51 - H
        let wL = 0.12 * p.wid, wR = 0.15 * p.wid
        let b = body(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, mid: p.mid ?? 0.5)
        if p.cable { cable(cx: cx, top: top) }
        shadow(b)
        paint(NSBezierPath(ovalIn: NSRect(x: cx - wL - 0.115, y: 0.5 - H * 0.6, width: 0.22, height: H * 0.78)), mix(s.body, .black, 0.08))
        paint(b, s.body)
        if let pc = p.panel { panels(b, cx: cx, wL: wL, wR: wR, top: top, bottom: bottom, color: pc) }
        buttons(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, split: 0.30, wheel: s.accent, style: p.wheel, dpi: p.dpi)
        sideButtons(n: p.side == 0 ? 2 : p.side, grid: false, x: cx - wL - 0.03, yMid: 0.42, color: s.accent)
        glyph(p.glyph.isEmpty ? "none" : p.glyph, cx + 0.02, bottom + 0.12, s.accent)
        gloss(cx - wL * 0.55, top - 0.1, 0.52, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
        ctx.restoreGState()
    }

    /// Trackballs: "thumb" (ball under the thumb, mouse-shaped body), "big" (large centre ball with a scroll ring),
    /// default centre ball.
    static func trackball(_ s: MouseSpec) {
        let p = s.p
        if p.ball == "thumb" {
            let cx: CGFloat = 0.55, top: CGFloat = 0.84, bottom: CGFloat = 0.16
            let b = body(cx: cx, top: top, bottom: bottom, wL: 0.2, wR: 0.22, mid: 0.42)
            shadow(b); paint(b, s.body)
            buttons(cx: cx, top: top, bottom: bottom, wL: 0.2, wR: 0.22, split: 0.33, wheel: mix(s.body, .white, 0.3), style: p.wheel)
            ball(at: NSPoint(x: cx - 0.13, y: 0.40), r: 0.10, color: s.accent)
            glyph(p.glyph.isEmpty ? "none" : p.glyph, cx + 0.06, 0.24, s.accent)
            gloss(cx - 0.12, 0.75, 0.58, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
            return
        }
        let big = p.ball == "big"
        let b = body(cx: 0.5, top: big ? 0.86 : 0.82, bottom: 0.15, wL: big ? 0.34 : 0.30, wR: big ? 0.34 : 0.30, mid: 0.5)
        shadow(b); paint(b, s.body)
        let bl = NSBezierPath(roundedRect: NSRect(x: 0.22, y: 0.19, width: 0.2, height: 0.075), xRadius: 0.035, yRadius: 0.035)
        let br = NSBezierPath(roundedRect: NSRect(x: 0.58, y: 0.19, width: 0.2, height: 0.075), xRadius: 0.035, yRadius: 0.035)
        paint(bl, mix(s.body, .white, 0.12), lw: 0.02); paint(br, mix(s.body, .white, 0.12), lw: 0.02)
        if big {   // scroll ring
            let ring = NSBezierPath(ovalIn: NSRect(x: 0.5 - 0.25, y: 0.58 - 0.25, width: 0.5, height: 0.5))
            ring.lineWidth = 0.04; mix(s.body, .white, 0.35).setStroke(); ring.stroke(); ring.lineWidth = 0.012; ink.setStroke(); ring.stroke()
        }
        ball(at: NSPoint(x: 0.5, y: 0.58), r: big ? 0.19 : 0.15, color: s.accent)
    }

    static func ball(at c: NSPoint, r: CGFloat, color: NSColor) {
        let ring = NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.03, y: c.y - r - 0.03, width: 2 * r + 0.06, height: 2 * r + 0.06))
        ink.withAlphaComponent(0.9).setFill(); ring.fill()
        let b = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        NSGradient(starting: mix(color, .white, 0.55), ending: mix(color, .black, 0.25))!.draw(in: b, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))
        ink.setStroke(); b.lineWidth = 0.025; b.stroke()
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - r * 0.5, y: c.y + r * 0.3, width: r * 0.42, height: r * 0.3)).fill()
    }

    static func magicMouse(_ s: MouseSpec) {
        let b = body(cx: 0.5, top: 0.88, bottom: 0.12, wL: 0.16, wR: 0.16, mid: 0.5)
        shadow(b); paint(b, s.body)
        if s.p.hinge {   // Arc-style bend
            for y in [0.47, 0.53] { let l = NSBezierPath(); l.move(to: NSPoint(x: 0.36, y: y)); l.line(to: NSPoint(x: 0.64, y: y)); l.lineWidth = 0.012; ink.withAlphaComponent(0.6).setStroke(); l.stroke() }
            let t = NSBezierPath(roundedRect: NSRect(x: 0.38, y: 0.6, width: 0.24, height: 0.2), xRadius: 0.05, yRadius: 0.05)
            s.accent.withAlphaComponent(0.35).setFill(); t.fill()
        } else {
            let touch = NSBezierPath(); touch.move(to: NSPoint(x: 0.5, y: 0.78)); touch.curve(to: NSPoint(x: 0.5, y: 0.34), controlPoint1: NSPoint(x: 0.46, y: 0.62), controlPoint2: NSPoint(x: 0.54, y: 0.5))
            s.accent.withAlphaComponent(0.55).setStroke(); touch.lineWidth = 0.022; touch.lineCapStyle = .round; touch.setLineDash([0.001, 0.05], count: 2, phase: 0); touch.stroke()
        }
        gloss(0.40, 0.80, 0.30, 0.95)
    }

    static func trackpad(_ s: MouseSpec) {
        let r = NSRect(x: 0.09, y: 0.22, width: 0.82, height: 0.56)
        let p = NSBezierPath(roundedRect: r, xRadius: 0.1, yRadius: 0.1)
        shadow(p); paint(p, s.body)
        let inner = NSBezierPath(roundedRect: r.insetBy(dx: 0.045, dy: 0.045), xRadius: 0.065, yRadius: 0.065)
        ink.withAlphaComponent(0.18).setStroke(); inner.lineWidth = 0.014; inner.stroke()
        let dots: [(CGFloat, CGFloat)] = s.p.glyph == "three" ? [(0.36, 0.52), (0.50, 0.55), (0.64, 0.52)] : [(0.42, 0.52), (0.60, 0.44)]
        for (x, y) in dots {
            let d = NSBezierPath(ovalIn: NSRect(x: x - 0.05, y: y - 0.05, width: 0.1, height: 0.1))
            s.accent.withAlphaComponent(0.35).setFill(); d.fill()
            s.accent.setStroke(); d.lineWidth = 0.018; d.stroke()
        }
        gloss(0.18, 0.70, 0.52, 0.8)
    }

    static func laptop(_ s: MouseSpec) {
        let deck = NSBezierPath(roundedRect: NSRect(x: 0.07, y: 0.17, width: 0.86, height: 0.66), xRadius: 0.08, yRadius: 0.08)
        shadow(deck); paint(deck, s.body)
        for i in 0..<3 {
            let row = NSBezierPath(roundedRect: NSRect(x: 0.17, y: 0.72 - CGFloat(i) * 0.075, width: 0.66, height: 0.045), xRadius: 0.02, yRadius: 0.02)
            ink.withAlphaComponent(0.45).setFill(); row.fill()
        }
        let pad = NSBezierPath(roundedRect: NSRect(x: 0.31, y: 0.22, width: 0.38, height: 0.25), xRadius: 0.05, yRadius: 0.05)
        paint(pad, mix(s.body, .white, 0.45), lw: 0.022)
        let d = NSBezierPath(ovalIn: NSRect(x: 0.47, y: 0.31, width: 0.07, height: 0.07))
        s.accent.setFill(); d.fill(); ink.setStroke(); d.lineWidth = 0.014; d.stroke()
    }
}
