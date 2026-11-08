import AppKit
import IOKit
import IOKit.hidsystem

// MARK: - Devices (event driven via IOKit notifications; no polling)

struct PointerDevice {
    let id: String
    let name: String
    let kind: Kind
    let transport: String
    let builtIn: Bool
    let spec: MouseSpec
    let product: String
    let vendor: Int
    let pid: Int
}

final class DeviceWatcher {
    var onChange: (() -> Void)?
    private var port: IONotificationPortRef?
    private var entries: [UInt64: PointerDevice] = [:]
    private var matchedIter: io_iterator_t = 0
    private var termIter: io_iterator_t = 0

    var devices: [PointerDevice] {
        var seen = Set<String>(), out: [PointerDevice] = []
        for d in entries.values.sorted(by: { $0.name < $1.name }) where seen.insert(d.id).inserted { out.append(d) }
        return out.sorted { ($0.kind == .mouse ? 0 : 1, $0.name) < ($1.kind == .mouse ? 0 : 1, $1.name) }
    }

    func start() {
        port = IONotificationPortCreate(kIOMainPortDefault)
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .commonModes)
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddMatchingNotification(port, kIOMatchedNotification, IOServiceMatching("IOHIDDevice"), { ref, it in
            Unmanaged<DeviceWatcher>.fromOpaque(ref!).takeUnretainedValue().drain(it, added: true)
        }, me, &matchedIter)
        drain(matchedIter, added: true)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOHIDDevice"), { ref, it in
            Unmanaged<DeviceWatcher>.fromOpaque(ref!).takeUnretainedValue().drain(it, added: false)
        }, me, &termIter)
        drain(termIter, added: false)
    }

    private func drain(_ it: io_iterator_t, added: Bool) {
        var changed = false
        while case let e = IOIteratorNext(it), e != 0 {
            var rid: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(e, &rid)
            if added {
                if let d = parse(e) { entries[rid] = d; changed = true }
            } else if entries.removeValue(forKey: rid) != nil { changed = true }
            IOObjectRelease(e)
        }
        if changed { onChange?() }
    }

    private func parse(_ e: io_registry_entry_t) -> PointerDevice? {
        var p: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(e, &p, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let d = p?.takeRetainedValue() as? [String: Any] else { return nil }
        guard (d["PrimaryUsagePage"] as? Int) == 1, (d["PrimaryUsage"] as? Int) == 2 || (d["PrimaryUsage"] as? Int) == 1 else { return nil }
        let product = d["Product"] as? String ?? "Pointing Device"
        let transport = d["Transport"] as? String ?? ""
        let lower = product.lowercased()
        if transport == "Virtual" || (lower.contains("keyboard") && !lower.contains("trackpad")) { return nil }
        let vendor = d["VendorID"] as? Int ?? 0, pid = d["ProductID"] as? Int ?? 0
        let builtIn = (d["Built-In"] as? Bool) ?? false
        let kind: Kind = lower.contains("trackpad") ? .trackpad : .mouse
        let spec = Catalog.match(product: product, manufacturer: d["Manufacturer"] as? String ?? "", vendor: vendor, kind: kind, builtIn: builtIn)
        let name = (builtIn && kind == .trackpad) ? "MacBook Trackpad" : product
        return PointerDevice(id: "\(vendor):\(pid):\(name)", name: name, kind: kind,
                             transport: transport == "FIFO" ? "Built-in" : (transport == "Bluetooth" || transport == "BluetoothLowEnergy" ? "Bluetooth" : (transport.isEmpty ? "" : transport)),
                             builtIn: builtIn, spec: spec, product: product, vendor: vendor, pid: pid)
    }
}

// MARK: - Per-device HID properties (IOHIDEventSystemClient; exported by IOKit, used by LinearMouse & co.)

@_silgen_name("IOHIDEventSystemClientCreateSimpleClient") private func hidClientCreate(_ a: CFAllocator?) -> Unmanaged<AnyObject>
@_silgen_name("IOHIDEventSystemClientCopyServices") private func hidCopyServices(_ c: AnyObject) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty") private func hidGet(_ s: AnyObject, _ k: CFString) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDServiceClientSetProperty") private func hidSet(_ s: AnyObject, _ k: CFString, _ v: AnyObject) -> Bool

enum HID {
    static let accelKeys = ["HIDMouseAcceleration", "HIDPointerAcceleration"]
    static let resKey = "HIDPointerResolution"
    static let defaultRes = 400 << 16
    private static var client: AnyObject?

    /// Services belonging to a device that carry pointer-acceleration properties.
    static func services(for d: PointerDevice) -> [AnyObject] {
        if client == nil { client = hidClientCreate(kCFAllocatorDefault).takeRetainedValue() }
        guard let c = client, let all = hidCopyServices(c)?.takeRetainedValue() as? [AnyObject] else { return [] }
        return all.filter { s in
            get(s, "Product") as? String == d.product && (get(s, "VendorID") as? Int ?? 0) == d.vendor &&
            (get(s, "ProductID") as? Int ?? 0) == d.pid && accelKeys.contains { get(s, $0) != nil }
        }
    }
    static func get(_ s: AnyObject, _ k: String) -> Any? { hidGet(s, k as CFString)?.takeRetainedValue() }
    @discardableResult static func set(_ s: AnyObject, _ k: String, _ v: Int) -> Bool { hidSet(s, k as CFString, NSNumber(value: v)) }
    static func supportsScale(_ d: PointerDevice) -> Bool { services(for: d).contains { get($0, resKey) != nil } }
}

// MARK: - Settings

struct Profile: Codable, Equatable {
    var speed: Double          // macOS tracking speed 0…3
    var flat: Bool             // acceleration off
    var scale: Double? = nil   // sensitivity multiplier via pointer resolution (DPI-style), 1 = default
    var relTo: String? = nil   // device id this profile is relative to (nil = absolute)
    var factor: Double? = nil  // multiplier vs. that device, e.g. 0.1, 1, 10
    var game: Double? = nil    // exact in-game multiplier on movement deltas (app rules only)
    var mult: Double { scale ?? 1 }
}

struct Resolved { var speed: Double; var mult: Double; var flat: Bool; var clamped: Bool }
struct AppRule: Codable { var name: String; var path: String; var profile: Profile }
struct DeviceSettings: Codable { var base: Profile; var managed: Bool; var apps: [String: AppRule] }
struct StoreData: Codable { var devices: [String: DeviceSettings] = [:]; var active: [String: String] = [:] }

final class Engine {
    static let shared = Engine()
    var data = StoreData()
    var connected: [PointerDevice] = []
    private let handle = NXOpenEventStatus()
    private var trackpadOriginal: Double?
    private var lastTrackpad: Double?
    private var touchedMice = Set<String>()      // device ids whose services we modified
    private var frontBundle: String?
    private var saveItem: DispatchWorkItem?
    private let file: URL = {
        let dir = ProcessInfo.processInfo.environment["SQUEAK_DATA"].map { URL(fileURLWithPath: $0) }   // override, e.g. demo mode
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Squeak")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }()

    init() {
        if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(StoreData.self, from: d) { data = s }
    }

    func key(_ k: Kind) -> CFString { (k == .mouse ? "HIDMouseAcceleration" : "HIDTrackpadAcceleration") as CFString }
    func systemSpeed(_ k: Kind) -> Double { var v = 0.0; IOHIDGetAccelerationWithKey(handle, key(k), &v); return v < 0 ? 0.6875 : v }

    func settings(for d: PointerDevice) -> DeviceSettings {
        data.devices[d.id] ?? DeviceSettings(base: Profile(speed: systemSpeed(d.kind), flat: false), managed: false, apps: [:])
    }
    func update(_ d: PointerDevice, _ f: (inout DeviceSettings) -> Void) {
        var s = settings(for: d); f(&s); s.managed = true
        data.devices[d.id] = s
        if d.kind == .trackpad { data.active[d.kind.rawValue] = d.id }
        commit()
    }
    func reset(_ d: PointerDevice) {
        data.devices[d.id] = nil
        if d.kind == .mouse { restoreMouse(d) }
        else if let o = trackpadOriginal { setGlobal(.trackpad, o); trackpadOriginal = nil; lastTrackpad = nil }
        commit(apply: false)
    }
    /// Trackpads still share one macOS setting (Apple's multitouch driver ignores per-device values), so one is "active".
    func makeActive(_ d: PointerDevice) { data.active[d.kind.rawValue] = d.id; commit() }
    func activeDevice(_ k: Kind) -> PointerDevice? {
        let list = connected.filter { $0.kind == k }
        if let id = data.active[k.rawValue], let d = list.first(where: { $0.id == id }) { return d }
        return list.last
    }

    private func setGlobal(_ k: Kind, _ v: Double) { IOHIDSetAccelerationWithKey(handle, key(k), v) }
    private func fixed(_ v: Double) -> Int { Int((v * 65536).rounded()) }

    private func profile(for s: DeviceSettings) -> Profile { frontBundle.flatMap { s.apps[$0]?.profile } ?? s.base }

    /// Effective gain of a device right now (speed × sensitivity), used as the reference for relative profiles.
    func gain(ofDevice id: String, depth: Int) -> Double {
        if let s = data.devices[id], s.managed { let r = resolve(profile(for: s), depth: depth + 1); return r.speed * r.mult }
        let kind = connected.first { $0.id == id }?.kind ?? (id.lowercased().contains("trackpad") ? .trackpad : .mouse)
        return systemSpeed(kind)
    }

    /// Turns a profile into concrete values. Relative: target = reference gain × factor; the speed curve tops out at 3,
    /// so anything above that spills into the sensitivity multiplier (when the device supports it).
    func resolve(_ p: Profile, depth: Int = 0, canScale: Bool = true) -> Resolved {
        guard let ref = p.relTo, depth < 4 else { return Resolved(speed: p.speed, mult: p.mult, flat: p.flat, clamped: false) }
        let target = gain(ofDevice: ref, depth: depth) * (p.factor ?? 1)
        if target <= 3 { return Resolved(speed: max(0, target), mult: 1, flat: p.flat, clamped: false) }
        return canScale ? Resolved(speed: 3, mult: target / 3, flat: p.flat, clamped: false) : Resolved(speed: 3, mult: 1, flat: p.flat, clamped: true)
    }

    /// Writes each mouse's own acceleration/resolution — truly per device, zero CPU, no permissions.
    /// Exact multipliers for the front app, keyed the way Scaler identifies devices.
    func scalerKey(_ d: PointerDevice) -> String { d.kind == .trackpad ? "trackpad" : "\(d.vendor):\(d.pid):\(d.product)" }

    func updateScaler() {
        var m: [String: Double] = [:]
        if let b = frontBundle {
            for d in connected {
                guard let s = data.devices[d.id], s.managed, let g = s.apps[b]?.profile.game, g != 1 else { continue }
                m[scalerKey(d)] = g
            }
        }
        Scaler.shared.update(scales: m)
    }

    func apply() {
        updateScaler()
        for d in connected where d.kind == .mouse {
            guard let s = data.devices[d.id], s.managed else { continue }
            let svcs = HID.services(for: d)
            let p = resolve(profile(for: s), canScale: svcs.contains { HID.get($0, HID.resKey) != nil })
            let accel = p.flat ? -65536 : fixed(p.speed)
            for svc in svcs {
                for k in HID.accelKeys where HID.get(svc, k) != nil { HID.set(svc, k, accel) }
                if HID.get(svc, HID.resKey) != nil { HID.set(svc, HID.resKey, Int(Double(HID.defaultRes) / max(0.1, p.mult))) }
            }
            touchedMice.insert(d.id)
        }
        if let d = activeDevice(.trackpad), let s = data.devices[d.id], s.managed {
            let p = resolve(profile(for: s), canScale: false), v = p.flat ? -1 : p.speed
            if lastTrackpad != v {
                if trackpadOriginal == nil { trackpadOriginal = systemSpeed(.trackpad) }
                setGlobal(.trackpad, v); lastTrackpad = v
            }
        }
    }

    private func restoreMouse(_ d: PointerDevice) {
        let sys = fixed(systemSpeed(.mouse))
        for svc in HID.services(for: d) {
            for k in HID.accelKeys where HID.get(svc, k) != nil { HID.set(svc, k, sys) }
            if HID.get(svc, HID.resKey) != nil { HID.set(svc, HID.resKey, HID.defaultRes) }
        }
        touchedMice.remove(d.id)
    }

    func frontChanged(_ app: NSRunningApplication?) {
        guard let id = app?.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        frontBundle = id
        apply()
    }

    func restoreOriginals() {
        for d in connected where touchedMice.contains(d.id) { restoreMouse(d) }
        if let o = trackpadOriginal { setGlobal(.trackpad, o) }
    }
    func reapplyForced() { lastTrackpad = nil; apply() }

    private func commit(apply doApply: Bool = true) {
        if doApply { apply() }
        saveItem?.cancel()
        let w = DispatchWorkItem { [self] in if let d = try? JSONEncoder().encode(data) { try? d.write(to: file, options: .atomic) } }
        saveItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }
    func flush() { saveItem?.perform() }
}
