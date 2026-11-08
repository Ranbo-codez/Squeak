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
        // tile
        let tile = NSBezierPath(roundedRect: NSRect(x: 0.01, y: 0.01, width: 0.98, height: 0.98), xRadius: 0.22, yRadius: 0.22)
        let white = NSColor.white
        NSGradient(starting: mix(s.accent, white, 0.80), ending: mix(s.accent, white, 0.55))!.draw(in: tile, angle: -60)
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
        ink.setStroke(); p.lineWidth = lw; p.lineJoinStyle = .round; p.stroke()
    }

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

    static func pill(_ r: NSRect, _ c: NSColor) {
        let p = NSBezierPath(roundedRect: r, xRadius: min(r.width, r.height) / 2, yRadius: min(r.width, r.height) / 2)
        paint(p, c, lw: 0.02)
    }

    static func buttons(cx: CGFloat, top: CGFloat, bottom: CGFloat, wL: CGFloat, wR: CGFloat, split: CGFloat, wheel: NSColor) {
        let yb = top - (top - bottom) * split
        let line = NSBezierPath()
        line.move(to: NSPoint(x: cx - wL * 0.97, y: yb + 0.012))
        line.curve(to: NSPoint(x: cx + wR * 0.97, y: yb + 0.012), controlPoint1: NSPoint(x: cx - wL * 0.4, y: yb - 0.035), controlPoint2: NSPoint(x: cx + wR * 0.4, y: yb - 0.035))
        line.move(to: NSPoint(x: cx, y: top - 0.012)); line.line(to: NSPoint(x: cx, y: yb - 0.012))
        ink.withAlphaComponent(0.85).setStroke(); line.lineWidth = 0.018; line.lineCapStyle = .round; line.stroke()
        pill(NSRect(x: cx - 0.027, y: yb + 0.02, width: 0.054, height: 0.115), wheel)
    }

    static func holes(clip: NSBezierPath, cx: CGFloat, y0: CGFloat, y1: CGFloat, w: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        var row = 0
        var y = y0
        while y < y1 {
            var x = cx - w + (row % 2 == 0 ? 0 : 0.03)
            while x < cx + w {
                let c = NSBezierPath(ovalIn: NSRect(x: x - 0.016, y: y - 0.016, width: 0.032, height: 0.032))
                ink.withAlphaComponent(0.78).setFill(); c.fill()
                x += 0.06
            }
            y += 0.052; row += 1
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    static func glow(cx: CGFloat, bottom: CGFloat, w: CGFloat, color: NSColor, rgb: Bool) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx - w * 0.62, y: bottom + 0.11))
        p.curve(to: NSPoint(x: cx + w * 0.62, y: bottom + 0.11), controlPoint1: NSPoint(x: cx - w * 0.3, y: bottom + 0.035), controlPoint2: NSPoint(x: cx + w * 0.3, y: bottom + 0.035))
        p.lineWidth = 0.032; p.lineCapStyle = .round
        if rgb {
            NSGraphicsContext.saveGraphicsState()
            let sh = NSShadow(); sh.shadowColor = color.withAlphaComponent(0.9); sh.shadowBlurRadius = 0.03; sh.set()
            color.setStroke(); p.stroke()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.withAlphaComponent(0.85).setStroke(); p.lineWidth = 0.012; p.stroke()
        } else {
            let d = NSBezierPath(ovalIn: NSRect(x: cx - 0.03, y: bottom + 0.1, width: 0.06, height: 0.06))
            color.setFill(); d.fill(); ink.setStroke(); d.lineWidth = 0.014; d.stroke()
        }
    }

    // MARK: shapes
    static func gamingMouse(_ s: MouseSpec, ergo: Bool, lite: Bool, logo: Bool = true) {
        let cx: CGFloat = 0.5, top: CGFloat = 0.87, bottom: CGFloat = 0.13
        let wL: CGFloat = ergo ? 0.185 : 0.19, wR: CGFloat = ergo ? 0.225 : 0.19
        let b = body(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, mid: ergo ? 0.40 : 0.45)
        shadow(b)
        if ergo { // thumb rest
            let t = NSBezierPath(ovalIn: NSRect(x: cx - wL - 0.06, y: 0.27, width: 0.12, height: 0.26))
            paint(t, mix(s.body, .black, 0.08))
        }
        paint(b, s.body)
        if lite { holes(clip: b, cx: cx, y0: bottom + 0.08, y1: top - (top - bottom) * 0.40, w: wL + 0.02) }
        buttons(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, split: lite ? 0.36 : 0.34, wheel: s.accent)
        if ergo {
            pill(NSRect(x: cx - wL - 0.03, y: 0.50, width: 0.07, height: 0.06), s.accent)
            pill(NSRect(x: cx - wL - 0.03, y: 0.42, width: 0.07, height: 0.06), s.accent)
        }
        if logo && (!lite || s.rgb) { glow(cx: cx, bottom: bottom, w: wL + wR, color: s.accent, rgb: s.rgb) }
        gloss(cx - wL * 0.62, top - 0.09, 0.50, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
    }

    static func officeMouse(_ s: MouseSpec, compact: Bool) {
        let cx: CGFloat = 0.52, top: CGFloat = compact ? 0.78 : 0.85, bottom: CGFloat = compact ? 0.20 : 0.14
        let wL: CGFloat = compact ? 0.15 : 0.17, wR: CGFloat = compact ? 0.17 : 0.22
        let b = body(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, mid: 0.42)
        shadow(b)
        if !compact { paint(NSBezierPath(ovalIn: NSRect(x: cx - wL - 0.075, y: 0.22, width: 0.15, height: 0.30)), mix(s.body, .black, 0.08)) }
        paint(b, s.body)
        buttons(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, split: 0.34, wheel: s.accent)
        if !compact { pill(NSRect(x: cx - wL - 0.02, y: 0.44, width: 0.045, height: 0.11), s.accent) } // thumb wheel
        let dot = NSBezierPath(ovalIn: NSRect(x: cx - 0.025, y: bottom + 0.1, width: 0.05, height: 0.05))
        s.accent.setFill(); dot.fill(); ink.setStroke(); dot.lineWidth = 0.014; dot.stroke()
        gloss(cx - wL * 0.6, top - 0.09, 0.50, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
    }

    static func verticalMouse(_ s: MouseSpec) {
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: 0.5, y: 0.5); ctx.rotate(by: -0.20); ctx.translateBy(x: -0.5, y: -0.5)
        let cx: CGFloat = 0.5, top: CGFloat = 0.90, bottom: CGFloat = 0.12
        let wL: CGFloat = 0.12, wR: CGFloat = 0.15
        let b = body(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, mid: 0.5)
        shadow(b)
        paint(NSBezierPath(ovalIn: NSRect(x: cx - wL - 0.115, y: 0.28, width: 0.22, height: 0.30)), mix(s.body, .black, 0.08))  // thumb lobe
        paint(b, s.body)
        buttons(cx: cx, top: top, bottom: bottom, wL: wL, wR: wR, split: 0.30, wheel: s.accent)
        pill(NSRect(x: cx - wL - 0.06, y: 0.43, width: 0.075, height: 0.05), s.accent)
        pill(NSRect(x: cx - wL - 0.06, y: 0.36, width: 0.075, height: 0.05), s.accent)
        gloss(cx - wL * 0.55, top - 0.1, 0.52, s.body.brightnessComponent > 0.6 ? 0.9 : 0.5)
        ctx.restoreGState()
    }

    static func trackball(_ s: MouseSpec) {
        let b = body(cx: 0.5, top: 0.82, bottom: 0.17, wL: 0.30, wR: 0.30, mid: 0.5)
        shadow(b); paint(b, s.body)
        // buttons
        let l = NSBezierPath(roundedRect: NSRect(x: 0.24, y: 0.21, width: 0.2, height: 0.075), xRadius: 0.035, yRadius: 0.035)
        let r = NSBezierPath(roundedRect: NSRect(x: 0.56, y: 0.21, width: 0.2, height: 0.075), xRadius: 0.035, yRadius: 0.035)
        paint(l, mix(s.body, .white, 0.12), lw: 0.02); paint(r, mix(s.body, .white, 0.12), lw: 0.02)
        // ball
        let ball = NSBezierPath(ovalIn: NSRect(x: 0.5 - 0.17, y: 0.58 - 0.17, width: 0.34, height: 0.34))
        let ring = NSBezierPath(ovalIn: NSRect(x: 0.5 - 0.20, y: 0.58 - 0.20, width: 0.40, height: 0.40))
        ink.withAlphaComponent(0.9).setFill(); ring.fill()
        NSGradient(starting: mix(s.accent, .white, 0.55), ending: mix(s.accent, .black, 0.25))!.draw(in: ball, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))
        ink.setStroke(); ball.lineWidth = 0.025; ball.stroke()
        let hi = NSBezierPath(ovalIn: NSRect(x: 0.42, y: 0.63, width: 0.07, height: 0.05))
        NSColor.white.withAlphaComponent(0.8).setFill(); hi.fill()
    }

    static func magicMouse(_ s: MouseSpec) {
        let b = body(cx: 0.5, top: 0.88, bottom: 0.12, wL: 0.16, wR: 0.16, mid: 0.5)
        shadow(b); paint(b, s.body)
        let touch = NSBezierPath(); touch.move(to: NSPoint(x: 0.5, y: 0.78)); touch.curve(to: NSPoint(x: 0.5, y: 0.34), controlPoint1: NSPoint(x: 0.46, y: 0.62), controlPoint2: NSPoint(x: 0.54, y: 0.5))
        s.accent.withAlphaComponent(0.55).setStroke(); touch.lineWidth = 0.022; touch.lineCapStyle = .round; touch.setLineDash([0.001, 0.05], count: 2, phase: 0); touch.stroke()
        gloss(0.40, 0.80, 0.30, 0.95)
    }

    static func trackpad(_ s: MouseSpec) {
        let r = NSRect(x: 0.09, y: 0.22, width: 0.82, height: 0.56)
        let p = NSBezierPath(roundedRect: r, xRadius: 0.1, yRadius: 0.1)
        shadow(p); paint(p, s.body)
        let inner = NSBezierPath(roundedRect: r.insetBy(dx: 0.045, dy: 0.045), xRadius: 0.065, yRadius: 0.065)
        ink.withAlphaComponent(0.18).setStroke(); inner.lineWidth = 0.014; inner.stroke()
        for (x, y) in [(0.42, 0.52), (0.60, 0.44)] {
            let d = NSBezierPath(ovalIn: NSRect(x: x - 0.05, y: y - 0.05, width: 0.1, height: 0.1))
            s.accent.withAlphaComponent(0.35).setFill(); d.fill()
            s.accent.setStroke(); d.lineWidth = 0.018; d.stroke()
        }
        gloss(0.18, 0.70, 0.52, 0.8)
    }

    static func laptop(_ s: MouseSpec) {
        let deck = NSBezierPath(roundedRect: NSRect(x: 0.07, y: 0.17, width: 0.86, height: 0.66), xRadius: 0.08, yRadius: 0.08)
        shadow(deck); paint(deck, s.body)
        for i in 0..<3 { // key rows
            let row = NSBezierPath(roundedRect: NSRect(x: 0.17, y: 0.72 - CGFloat(i) * 0.075, width: 0.66, height: 0.045), xRadius: 0.02, yRadius: 0.02)
            ink.withAlphaComponent(0.45).setFill(); row.fill()
        }
        let pad = NSBezierPath(roundedRect: NSRect(x: 0.31, y: 0.22, width: 0.38, height: 0.25), xRadius: 0.05, yRadius: 0.05)
        paint(pad, mix(s.body, .white, 0.45), lw: 0.022)
        let d = NSBezierPath(ovalIn: NSRect(x: 0.47, y: 0.31, width: 0.07, height: 0.07))
        s.accent.setFill(); d.fill(); ink.setStroke(); d.lineWidth = 0.014; d.stroke()
    }
}
