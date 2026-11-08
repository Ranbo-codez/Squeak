import AppKit

enum Kind: String, Codable { case mouse, trackpad }

enum Shape: String {
    case ambi, ergo, ambiLite, ergoLite   // gaming bodies (Lite = honeycomb shell)
    case office, compact, vert, ball      // work bodies
    case flat, trackpad, laptop           // Apple-style surfaces
}

struct MouseSpec {
    let brand: String
    let name: String
    let key: String          // normalised substring matched against the device's product string
    let shape: Shape
    let body: NSColor
    let accent: NSColor
    let rgb: Bool
    let category: String     // "Gaming", "Ergonomic", "Apple", "Generic"
    var p = IconParams()
}

/// Per-model drawing details, so every catalog entry gets its own icon rather than a recoloured template.
/// These are stylised, not exact likenesses.
struct IconParams {
    var len: CGFloat = 1, wid: CGFloat = 1, mid: CGFloat? = nil, tilt: CGFloat? = nil
    var side = 0, rside = 0
    var grid = false, paddle = false, sniper = false, dpi = false, cable = false, wing = false, nothumb = false, hinge = false
    var pat = "", glyph = "", wheel = "", ball = ""
    var stripe: NSColor?, panel: NSColor?, tile: NSColor?

    init() {}
    init(_ flags: String) {
        for t in flags.split(separator: " ") {
            let kv = t.split(separator: "=", maxSplits: 1).map(String.init)
            let k = kv[0], v = kv.count > 1 ? kv[1] : ""
            let d = CGFloat(Double(v) ?? 1)
            switch k {
            case "len": len = d
            case "wid": wid = d
            case "mid": mid = d
            case "tilt": tilt = d
            case "side": side = Int(v) ?? 0
            case "rside": rside = Int(v) ?? 0
            case "grid": grid = true
            case "paddle": paddle = true
            case "sniper": sniper = true
            case "dpi": dpi = true
            case "cable": cable = true
            case "wing": wing = true
            case "nothumb": nothumb = true
            case "hinge": hinge = true
            case "pat": pat = v
            case "glyph": glyph = v
            case "wheel": wheel = v
            case "ball": ball = v
            case "stripe": stripe = hex(v)
            case "panel": panel = hex(v)
            case "tile": tile = hex(v)
            default: break
            }
        }
    }
}

func shiftHue(_ c: NSColor, _ d: CGFloat, sat: CGFloat = 1) -> NSColor {
    guard let rgb = c.usingColorSpace(.sRGB) else { return c }
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    if s < 0.15 { return c }   // greys/whites have no hue to shift
    return NSColor(hue: (h + d + 1).truncatingRemainder(dividingBy: 1), saturation: s * sat, brightness: b, alpha: 1)
}

func norm(_ s: String) -> String { String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }) }

func hex(_ h: String) -> NSColor {
    let v = UInt32(h, radix: 16) ?? 0x888888
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}

/// 75 gaming mice + 25 ergonomic/work mice + Apple + generic fallbacks.
/// Row format: Brand|Name|match key|shape|body hex|accent hex|flags
enum Catalog {
    static let rows = """
    [Gaming]
    Razer|Viper V3 Pro|viper v3 pro|ambi|1b1b1b|44d62c|len=1.05 wid=0.9 side=2 glyph=tri
    Razer|Viper V2 Pro|viper v2 pro|ambi|f2f2f2|44d62c|len=1.05 wid=0.9 side=2 glyph=tri
    Razer|Viper Ultimate|viper ultimate|ambi|1b1b1b|44d62c|rgb side=2 rside=2 glyph=tri
    Razer|Viper Mini|viper mini|ambi|1b1b1b|44d62c|rgb cable len=0.84 wid=0.9 side=2 glyph=tri
    Razer|DeathAdder V3 Pro|deathadder v3 pro|ergo|f2f2f2|44d62c|side=2 glyph=tri
    Razer|DeathAdder V3|deathadder v3|ergo|1b1b1b|44d62c|cable side=2 glyph=tri
    Razer|DeathAdder Essential|deathadder|ergo|2a2a2a|44d62c|cable side=2 glyph=ring wheel=wide len=0.96
    Razer|Basilisk V3 Pro|basilisk v3 pro|ergo|f2f2f2|44d62c|rgb paddle side=3 wheel=metal glyph=tri
    Razer|Basilisk V3|basilisk|ergo|1b1b1b|44d62c|rgb cable paddle side=3 glyph=tri
    Razer|Naga V2 Pro|naga|ergo|1b1b1b|44d62c|rgb grid wid=1.08 glyph=tri
    Razer|Cobra Pro|cobra pro|ambi|1b1b1b|44d62c|rgb dpi len=0.9 wid=0.95 side=2 glyph=tri
    Razer|Orochi V2|orochi|ambi|e9e9ef|44d62c|len=0.78 wid=0.84 side=2 glyph=tri
    Logitech|G Pro X Superlight 2|superlight 2|ambi|f2f2f2|00b8fc|side=2 rside=2 glyph=chev
    Logitech|G Pro X Superlight|superlight|ambi|1b1b1b|00b8fc|side=2 rside=2 glyph=chev
    Logitech|G502 X|g502 x|ergo|f2f2f2|00b8fc|side=3 dpi sniper wheel=metal panel=c4c8d0 glyph=chev
    Logitech|G502 Hero|g502|ergo|1b1b1b|00b8fc|rgb cable side=3 dpi sniper wheel=metal panel=4a4f5a glyph=chev
    Logitech|G305|g305|ambi|c9b8f0|00b8fc|len=0.92 side=2 glyph=chev
    Logitech|G203|g203|ambi|1b1b1b|8a5cff|rgb cable len=0.95 side=2 glyph=chev
    Logitech|G903|g903|ambi|1b1b1b|00b8fc|rgb dpi side=2 rside=2 wheel=metal panel=5a5f6a glyph=chev
    Logitech|G Pro Wireless|g pro wireless|ambi|f2f2f2|00b8fc|rgb side=2 rside=2 stripe=2f3540 glyph=chev
    Logitech|G102|g102|ambi|f2f2f2|ff4d6d|rgb cable len=0.95 side=2 glyph=chev
    Logitech|G402|g402|ergo|1b1b1b|00b8fc|cable side=4 dpi wheel=wide panel=3a3f4a glyph=chev
    Logitech|G604|g604|ergo|2f3540|00b8fc|side=6 dpi wheel=metal glyph=chev
    Logitech|G705|g705|ergo|f7c5e1|ff5cb8|rgb len=0.86 side=2 glyph=chev
    Finalmouse|Starlight-12|starlight|ambiLite|c9d6e8|6ea8ff|pat=holes side=2 glyph=star
    Finalmouse|Starlight Pro|starlight pro|ambiLite|ffe9a8|ffb020|pat=hex side=2 glyph=star
    Finalmouse|UltralightX|ultralightx|ambiLite|2a2a2a|ffffff|pat=slots side=2 tile=c9c9dc glyph=star
    Finalmouse|Ultralight 2|ultralight 2|ambiLite|f4f4f4|9aa0ff|pat=holes stripe=1b1b1b side=2 glyph=star
    Zowie|EC2-CW|ec2|ergo|2a2a2a|ff3b3b|side=2 glyph=ring
    Zowie|EC1-CW|ec1|ergo|2a2a2a|ff3b3b|len=1.08 wid=1.06 side=2 wheel=wide glyph=ring
    Zowie|ZA11-C|za11|ambi|2a2a2a|ff3b3b|cable mid=0.33 side=2 rside=2 glyph=ring
    Zowie|FK2-C|fk2|ambi|2a2a2a|ff3b3b|cable mid=0.52 wid=1.04 len=0.96 side=2 rside=2 glyph=ring
    Zowie|S2-C|zowie s2|ambi|2a2a2a|ff3b3b|cable len=0.9 side=2 glyph=ring
    SteelSeries|Aerox 3|aerox 3|ambiLite|1b1b1b|ff5200|rgb pat=holes len=0.94 side=2 glyph=bolt
    SteelSeries|Aerox 5|aerox 5|ergoLite|f2f2f2|ff5200|rgb pat=holes side=5 glyph=bolt
    SteelSeries|Aerox 9|aerox 9|ergoLite|1b1b1b|ff5200|rgb pat=holes grid glyph=bolt
    SteelSeries|Prime Wireless|prime|ambi|f2f2f2|ff5200|side=2 wheel=wide glyph=bolt
    SteelSeries|Rival 3|rival 3|ambi|f2f2f2|ff5200|rgb cable side=2 glyph=bolt
    SteelSeries|Rival 5|rival 5|ergo|1b1b1b|ff5200|rgb cable side=5 glyph=bolt
    Glorious|Model O|model o|ambiLite|1b1b1b|ff4fd8|rgb cable pat=hex side=2 glyph=diamond
    Glorious|Model O 2 Pro|model o 2|ambiLite|f2f2f2|ff4fd8|pat=hex side=2 glyph=diamond
    Glorious|Model D|model d|ergoLite|1b1b1b|ff4fd8|rgb cable pat=hex side=2 glyph=diamond
    Glorious|Model D 2 Pro|model d 2|ergoLite|f2f2f2|ff4fd8|pat=hex side=2 glyph=diamond
    Glorious|Model I|model i|ergoLite|1b1b1b|ff4fd8|rgb pat=slots side=4 glyph=diamond
    Pulsar|X2|pulsar x2|ambi|f2f2f2|ff3b3b|mid=0.5 len=0.95 side=2 rside=2 glyph=plus
    Pulsar|X2 V2|x2 v2|ambi|1b1b1b|ff3b3b|mid=0.5 len=0.95 side=2 rside=2 glyph=plus
    Pulsar|Xlite V3|xlite|ergoLite|f2f2f2|ff3b3b|pat=holes side=2 glyph=plus
    Lamzu|Maya|maya|ambiLite|f6b7d2|ff6fae|pat=holes len=0.95 side=2 glyph=wave
    Lamzu|Atlantis|atlantis|ambiLite|bfe3ff|3d9bff|pat=slots side=2 glyph=wave
    Endgame Gear|XM2we|xm2|ambi|1b1b1b|ffcf00|wid=0.92 side=2 glyph=hex
    Endgame Gear|OP1we|op1|ambi|f2f2f2|ffcf00|len=0.88 wid=0.88 side=2 glyph=hex
    VAXEE|XE|vaxee xe|ergo|f2f2f2|2a2a2a|side=2 glyph=none
    VAXEE|ZYGEN NP-01|zygen|ergo|2a2a2a|ffffff|side=2 tile=d5d5e2 glyph=none mid=0.45
    Corsair|Dark Core RGB Pro|dark core|ergo|1b1b1b|ffd400|rgb wing side=3 glyph=sail
    Corsair|M65 RGB Elite|m65|ergo|1b1b1b|ffd400|rgb cable sniper side=2 panel=7a7f88 glyph=sail
    Corsair|Scimitar Elite|scimitar|ergo|f2f2f2|ffd400|rgb cable grid glyph=sail
    Corsair|Harpoon RGB|harpoon|ambi|1b1b1b|ffd400|rgb cable len=0.9 side=2 glyph=sail
    Corsair|Sabre Pro|sabre|ambi|1b1b1b|ffd400|rgb cable len=1.02 side=2 stripe=ffd400 glyph=sail
    HyperX|Pulsefire Haste 2|haste 2|ambiLite|f2f2f2|e5202e|pat=holes side=2 glyph=x
    HyperX|Pulsefire Haste|haste|ambiLite|1b1b1b|e5202e|cable pat=hex side=2 glyph=x
    HyperX|Pulsefire Surge|surge|ambi|1b1b1b|e5202e|rgb cable side=2 glyph=x
    Roccat|Kone Pro|kone|ergoLite|1b1b1b|3df2ff|rgb pat=slots side=2 glyph=dot
    Roccat|Burst Pro|burst|ambiLite|1b1b1b|3df2ff|rgb cable pat=hex side=2 glyph=dot
    ASUS ROG|Gladius III|gladius|ergo|f2f2f2|ff1744|rgb dpi side=2 glyph=sail
    ASUS ROG|Keris Wireless|keris|ambi|f2f2f2|ff1744|rgb len=0.92 side=2 glyph=sail
    ASUS ROG|Harpe Ace|harpe|ambiLite|1b1b1b|ff1744|pat=slots side=2 glyph=sail
    Cooler Master|MM720|mm720|ambiLite|1b1b1b|b45cff|rgb pat=holes mid=0.62 wid=1.06 len=0.86 side=2 glyph=dot
    Cooler Master|MM711|mm711|ambiLite|1b1b1b|b45cff|rgb cable pat=holes wid=0.95 side=2 glyph=dot
    Redragon|M602 Griffin|m602|ergo|1b1b1b|ff2a2a|rgb cable side=2 panel=3a3a3a glyph=dot
    Redragon|M711 Cobra|m711|ambi|1b1b1b|ff2a2a|rgb cable side=2 stripe=ff2a2a glyph=dot
    Alienware|AW720M|aw720|ambi|1b1b1b|00e5ff|rgb side=2 rside=2 glyph=ring
    MSI|Clutch GM41|gm41|ambi|1b1b1b|ff2a2a|rgb cable len=0.97 wid=0.95 side=2 panel=3a3a3a glyph=tri
    Keychron|M3|keychron m3|ambi|f2f2f2|ffb800|side=2 glyph=dot len=0.95
    Mad Catz|R.A.T. 8+|rat8|ergo|2a2a2a|ff6a00|pat=cut panel=8a8f98 sniper side=2 glyph=none
    Mionix|Naos|naos|ergo|f4f4f4|26d0ce|rgb cable len=1.05 wid=1.08 side=2 glyph=ring
    [Ergonomic]
    Logitech|MX Master 4|mx master 4|office|2c3038|2dd4bf|side=2 wheel=metal panel=6b7280
    Logitech|MX Master 3S|mx master 3s|office|3b414d|2dd4bf|side=2 wheel=metal
    Logitech|MX Master 3|mx master 3|office|d9dde3|2dd4bf|side=2 wheel=metal
    Logitech|MX Anywhere 3S|mx anywhere 3s|compact|3b414d|2dd4bf|wheel=metal side=2
    Logitech|MX Anywhere 3|mx anywhere 3|compact|f4c6d2|ff7aa8|wheel=metal side=2
    Logitech|MX Vertical|mx vertical|vert|3b414d|2dd4bf|wheel=metal side=2
    Logitech|Lift|lift|vert|f4b8c8|ff7aa8|len=0.86 side=2
    Logitech|MX Ergo S|mx ergo|ball|3b414d|2dd4bf|ball=thumb wheel=metal
    Logitech|Ergo M575|m575|ball|d9dde3|4aa3ff|ball=thumb
    Logitech|Pebble Mouse 2 M350s|pebble|compact|c9b8f0|8f6bff|len=0.8 wid=1.08 glyph=none
    Logitech|M720 Triathlon|m720|office|2a2a2a|4aa3ff|nothumb side=3 wid=0.9 len=0.95
    Logitech|Trackman Marble|marble|ball|3b414d|ff4d4d|glyph=none
    Microsoft|Sculpt Ergonomic|sculpt|office|2a2a2a|4aa3ff|wid=1.12 len=0.92 nothumb panel=4aa3ff
    Microsoft|Ergonomic Mouse|ergonomic mouse|office|c9ccd3|4aa3ff|nothumb side=2
    Microsoft|Surface Precision|surface precision|office|d9dde3|4aa3ff|side=3
    Microsoft|Arc Mouse|arc mouse|flat|3b414d|4aa3ff|hinge
    Anker|Vertical Ergonomic|anker|vert|2a2a2a|ff9f1c|cable
    Evoluent|VerticalMouse 4|evoluent|vert|d9dde3|4aa3ff|len=1.05 side=3 tilt=0.5
    Kensington|Orbit Trackball|orbit|ball|2a2a2a|ff4d4d|ball=big
    Kensington|Expert Mouse|expert mouse|ball|3b414d|9aa3b5|ball=big
    Kensington|Pro Fit Ergo|pro fit|vert|3b414d|ff4d4d|tilt=1.4 side=2
    Contour|Unimouse|unimouse|vert|d9dde3|7bd88f|tilt=1.6 wid=1.1
    ProtoArc|EM03|protoarc|vert|d9dde3|ff8a5c|side=2 panel=ff8a5c
    Razer|Pro Click|pro click|office|f2f2f2|44d62c|side=2 nothumb
    Elecom|HUGE Trackball|huge|ball|d9dde3|ff8a3d|ball=big
    [Apple]
    Apple|Magic Mouse|magic mouse|flat|f1f1f4|5aa9ff|
    Apple|Magic Trackpad|magic trackpad|trackpad|e6e8ee|5aa9ff|
    Apple|MacBook Trackpad|internal keyboard trackpad|laptop|8e939d|5aa9ff|
    [Generic]
    Generic|Generic Gaming Mouse|gaming mouse|ergo|2a2a2a|7a5cff|rgb side=2 glyph=dot
    Generic|Generic Mouse|zzgenericmouse|compact|e4e6eb|6b7cff|
    Generic|Generic Trackpad|zzgenerictrackpad|trackpad|d9dde3|6b7cff|glyph=three
    """

    static let all: [MouseSpec] = {
        var out: [MouseSpec] = []
        var cat = ""
        var brandCount: [String: Int] = [:]
        for line in rows.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("[") { cat = String(l.dropFirst().dropLast()); continue }
            let f = l.components(separatedBy: "|")
            guard f.count >= 7, let shape = Shape(rawValue: f[3]) else { continue }
            var p = IconParams(f[6])
            if p.tile == nil {   // vary the tile shade between models of the same brand so they don't blur together
                let i = brandCount[f[0], default: 0]; brandCount[f[0]] = i + 1
                let steps: [CGFloat] = [0, 0.07, -0.07, 0.14, -0.14, 0.21, -0.21, 0.28, -0.28, 0.35, -0.35, 0.42]
                p.tile = shiftHue(hex(f[5]), steps[i % steps.count], sat: i >= steps.count ? 0.6 : 1)
            }
            out.append(MouseSpec(brand: f[0], name: f[1], key: norm(f[2]), shape: shape,
                                 body: hex(f[4]), accent: hex(f[5]), rgb: f[6].split(separator: " ").contains("rgb"), category: cat, p: p))
        }
        return out
    }()

    /// Brand fallback by USB/BT vendor ID or manufacturer string.
    static let vendors: [Int: (String, String, String)] = [   // id -> (brand, body, accent)
        0x1532: ("Razer", "1b1b1b", "44d62c"), 0x046D: ("Logitech", "2a2f3a", "00b8fc"),
        0x1038: ("SteelSeries", "1b1b1b", "ff5200"), 0x258A: ("Glorious", "1b1b1b", "ff4fd8"),
        0x1B1C: ("Corsair", "1b1b1b", "ffd400"), 0x0951: ("HyperX", "1b1b1b", "e5202e"),
        0x1E7D: ("Roccat", "1b1b1b", "3df2ff"), 0x0B05: ("ASUS ROG", "1b1b1b", "ff1744"),
        0x2516: ("Cooler Master", "1b1b1b", "b45cff"), 0x047D: ("Kensington", "3b414d", "ff4d4d"),
        0x045E: ("Microsoft", "3b414d", "4aa3ff"),
    ]

    static func match(product: String, manufacturer: String, vendor: Int, kind: Kind, builtIn: Bool) -> MouseSpec {
        let p = norm(product)
        var best: MouseSpec?
        for s in all where p.contains(s.key) && (best == nil || s.key.count > best!.key.count) { best = s }
        if let b = best { return b }
        if kind == .trackpad {
            return builtIn ? all.first { $0.shape == .laptop }! : all.first { $0.name == "Generic Trackpad" }!
        }
        var found = vendors[vendor]
        if found == nil { found = vendors.values.first { norm(manufacturer).contains(norm($0.0)) } }
        if let v = found {
            let gaming = ["Razer", "SteelSeries", "Glorious", "Corsair", "HyperX", "Roccat", "ASUS ROG", "Cooler Master"].contains(v.0)
            return MouseSpec(brand: v.0, name: "\(v.0) Mouse", key: "", shape: gaming ? .ergo : .compact,
                             body: hex(v.1), accent: hex(v.2), rgb: gaming, category: gaming ? "Gaming" : "Generic")
        }
        return all.first { $0.name == "Generic Mouse" }!
    }
}
