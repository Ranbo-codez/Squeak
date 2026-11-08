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
    Razer|Viper V3 Pro|viper v3 pro|ambiLite|1b1b1b|44d62c|
    Razer|Viper V2 Pro|viper v2 pro|ambiLite|f2f2f2|44d62c|
    Razer|Viper Ultimate|viper ultimate|ambi|1b1b1b|44d62c|rgb
    Razer|Viper Mini|viper mini|ambi|1b1b1b|44d62c|
    Razer|DeathAdder V3 Pro|deathadder v3 pro|ergo|f2f2f2|44d62c|
    Razer|DeathAdder V3|deathadder v3|ergo|1b1b1b|44d62c|
    Razer|DeathAdder Essential|deathadder|ergo|1b1b1b|44d62c|
    Razer|Basilisk V3 Pro|basilisk v3 pro|ergo|1b1b1b|44d62c|rgb
    Razer|Basilisk V3|basilisk|ergo|1b1b1b|44d62c|rgb
    Razer|Naga V2 Pro|naga|ergo|1b1b1b|44d62c|rgb
    Razer|Cobra Pro|cobra pro|ambi|1b1b1b|44d62c|rgb
    Razer|Orochi V2|orochi|ambi|1b1b1b|44d62c|
    Logitech|G Pro X Superlight 2|superlight 2|ambi|f2f2f2|00b8fc|
    Logitech|G Pro X Superlight|superlight|ambi|1b1b1b|00b8fc|
    Logitech|G502 X|g502 x|ergo|1b1b1b|00b8fc|rgb
    Logitech|G502 Hero|g502|ergo|1b1b1b|00b8fc|rgb
    Logitech|G305|g305|ambi|1b1b1b|00b8fc|
    Logitech|G203|g203|ambi|1b1b1b|8a5cff|rgb
    Logitech|G903|g903|ambi|1b1b1b|00b8fc|rgb
    Logitech|G Pro Wireless|g pro wireless|ambi|1b1b1b|00b8fc|rgb
    Logitech|G102|g102|ambi|1b1b1b|ff4d6d|rgb
    Logitech|G402|g402|ambi|1b1b1b|00b8fc|
    Logitech|G604|g604|ergo|1b1b1b|00b8fc|
    Logitech|G705|g705|ergo|f7c5e1|ff5cb8|
    Finalmouse|Starlight-12|starlight|ambiLite|c9d6e8|6ea8ff|
    Finalmouse|Starlight Pro|starlight pro|ambiLite|ffe9a8|ffb020|
    Finalmouse|UltralightX|ultralightx|ambiLite|2a2a2a|ffffff|
    Finalmouse|Ultralight 2|ultralight 2|ambiLite|e8e8ec|9aa0ff|
    Zowie|EC2-CW|ec2|ergo|2a2a2a|ff3b3b|
    Zowie|EC1-CW|ec1|ergo|2a2a2a|ff3b3b|
    Zowie|ZA11-C|za11|ambi|2a2a2a|ff3b3b|
    Zowie|FK2-C|fk2|ambi|2a2a2a|ff3b3b|
    Zowie|S2-C|zowie s2|ambi|2a2a2a|ff3b3b|
    SteelSeries|Aerox 3|aerox 3|ambiLite|1b1b1b|ff5200|rgb
    SteelSeries|Aerox 5|aerox 5|ergoLite|1b1b1b|ff5200|rgb
    SteelSeries|Aerox 9|aerox 9|ergoLite|1b1b1b|ff5200|rgb
    SteelSeries|Prime Wireless|prime|ambi|1b1b1b|ff5200|
    SteelSeries|Rival 3|rival 3|ambi|1b1b1b|ff5200|rgb
    SteelSeries|Rival 5|rival 5|ergo|1b1b1b|ff5200|rgb
    Glorious|Model O|model o|ambiLite|1b1b1b|ff4fd8|rgb
    Glorious|Model O 2 Pro|model o 2|ambiLite|f2f2f2|ff4fd8|
    Glorious|Model D|model d|ergoLite|1b1b1b|ff4fd8|rgb
    Glorious|Model D 2 Pro|model d 2|ergoLite|f2f2f2|ff4fd8|
    Glorious|Model I|model i|ergoLite|1b1b1b|ff4fd8|rgb
    Pulsar|X2|pulsar x2|ambi|f2f2f2|ff3b3b|
    Pulsar|X2 V2|x2 v2|ambi|1b1b1b|ff3b3b|
    Pulsar|Xlite V3|xlite|ambiLite|f2f2f2|ff3b3b|
    Lamzu|Maya|maya|ambiLite|f6b7d2|ff6fae|
    Lamzu|Atlantis|atlantis|ambiLite|bfe3ff|3d9bff|
    Endgame Gear|XM2we|xm2|ambi|1b1b1b|ffcf00|
    Endgame Gear|OP1we|op1|ambi|1b1b1b|ffcf00|
    VAXEE|XE|vaxee xe|ambi|f2f2f2|2a2a2a|
    VAXEE|ZYGEN NP-01|zygen|ambi|2a2a2a|ffffff|
    Corsair|Dark Core RGB Pro|dark core|ergo|1b1b1b|ffd400|rgb
    Corsair|M65 RGB Elite|m65|ergo|1b1b1b|ffd400|rgb
    Corsair|Scimitar Elite|scimitar|ergo|1b1b1b|ffd400|rgb
    Corsair|Harpoon RGB|harpoon|ambi|1b1b1b|ffd400|rgb
    Corsair|Sabre Pro|sabre|ambi|1b1b1b|ffd400|rgb
    HyperX|Pulsefire Haste 2|haste 2|ambiLite|1b1b1b|e5202e|
    HyperX|Pulsefire Haste|haste|ambiLite|1b1b1b|e5202e|
    HyperX|Pulsefire Surge|surge|ambi|1b1b1b|e5202e|rgb
    Roccat|Kone Pro|kone|ergo|1b1b1b|3df2ff|rgb
    Roccat|Burst Pro|burst|ambiLite|1b1b1b|3df2ff|rgb
    ASUS ROG|Gladius III|gladius|ergo|1b1b1b|ff1744|rgb
    ASUS ROG|Keris Wireless|keris|ambi|1b1b1b|ff1744|rgb
    ASUS ROG|Harpe Ace|harpe|ambiLite|1b1b1b|ff1744|
    Cooler Master|MM720|mm720|ambiLite|1b1b1b|b45cff|rgb
    Cooler Master|MM711|mm711|ambiLite|1b1b1b|b45cff|rgb
    Redragon|M602 Griffin|m602|ambi|1b1b1b|ff2a2a|rgb
    Redragon|M711 Cobra|m711|ambi|1b1b1b|ff2a2a|rgb
    Alienware|AW720M|aw720|ergo|1b1b1b|00e5ff|rgb
    MSI|Clutch GM41|gm41|ambi|1b1b1b|ff2a2a|rgb
    Keychron|M3|keychron m3|ambiLite|f2f2f2|ffb800|
    Mad Catz|R.A.T. 8+|rat8|ergo|2a2a2a|ff6a00|
    Mionix|Naos|naos|ergo|1b1b1b|26d0ce|rgb
    [Ergonomic]
    Logitech|MX Master 4|mx master 4|office|3b414d|2dd4bf|
    Logitech|MX Master 3S|mx master 3s|office|3b414d|2dd4bf|
    Logitech|MX Master 3|mx master 3|office|d9dde3|2dd4bf|
    Logitech|MX Anywhere 3S|mx anywhere 3s|compact|3b414d|2dd4bf|
    Logitech|MX Anywhere 3|mx anywhere 3|compact|d9dde3|2dd4bf|
    Logitech|MX Vertical|mx vertical|vert|3b414d|2dd4bf|
    Logitech|Lift|lift|vert|f4b8c8|ff7aa8|
    Logitech|MX Ergo S|mx ergo|ball|3b414d|2dd4bf|
    Logitech|Ergo M575|m575|ball|d9dde3|4aa3ff|
    Logitech|Pebble Mouse 2 M350s|pebble|compact|c9b8f0|8f6bff|
    Logitech|M720 Triathlon|m720|office|3b414d|4aa3ff|
    Logitech|Trackman Marble|marble|ball|3b414d|ff8a3d|
    Microsoft|Sculpt Ergonomic|sculpt|office|3b414d|4aa3ff|
    Microsoft|Ergonomic Mouse|ergonomic mouse|office|3b414d|4aa3ff|
    Microsoft|Surface Precision|surface precision|office|d9dde3|4aa3ff|
    Microsoft|Arc Mouse|arc mouse|flat|3b414d|4aa3ff|
    Anker|Vertical Ergonomic|anker|vert|3b414d|ff9f1c|
    Evoluent|VerticalMouse 4|evoluent|vert|d9dde3|4aa3ff|
    Kensington|Orbit Trackball|orbit|ball|3b414d|ff4d4d|
    Kensington|Expert Mouse|expert mouse|ball|3b414d|ff4d4d|
    Kensington|Pro Fit Ergo|pro fit|vert|3b414d|ff4d4d|
    Contour|Unimouse|unimouse|vert|d9dde3|7bd88f|
    ProtoArc|EM03|protoarc|vert|d9dde3|ff8a5c|
    Razer|Pro Click|pro click|office|f2f2f2|44d62c|
    Elecom|HUGE Trackball|huge|ball|3b414d|ff8a3d|
    [Apple]
    Apple|Magic Mouse|magic mouse|flat|f1f1f4|5aa9ff|
    Apple|Magic Trackpad|magic trackpad|trackpad|e6e8ee|5aa9ff|
    Apple|MacBook Trackpad|internal keyboard trackpad|laptop|8e939d|5aa9ff|
    [Generic]
    Generic|Generic Gaming Mouse|gaming mouse|ergo|2a2a2a|7a5cff|rgb
    Generic|Generic Mouse|zzgenericmouse|compact|e4e6eb|6b7cff|
    Generic|Generic Trackpad|zzgenerictrackpad|trackpad|d9dde3|6b7cff|
    """

    static let all: [MouseSpec] = {
        var out: [MouseSpec] = []
        var cat = ""
        for line in rows.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("[") { cat = String(l.dropFirst().dropLast()); continue }
            let f = l.components(separatedBy: "|")
            guard f.count >= 7, let shape = Shape(rawValue: f[3]) else { continue }
            out.append(MouseSpec(brand: f[0], name: f[1], key: norm(f[2]), shape: shape,
                                 body: hex(f[4]), accent: hex(f[5]), rgb: f[6].contains("rgb"), category: cat))
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
