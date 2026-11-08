import AppKit
import IOKit.hid
import ApplicationServices

/// Exact in-game multiplier. While an app with a game-scale rule is in front, multiplies the movement deltas
/// that apps (e.g. a game's locked camera) read from mouse events. The cursor position itself is left alone.
/// Off (no tap, no HID listener) whenever no such rule applies, so it costs nothing otherwise.
final class Scaler {
    static let shared = Scaler()

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var manager: IOHIDManager?
    private(set) var running = false

    /// Last raw X/Y report time per device key ("vendor:pid:product"). Multitouch trackpads don't send these,
    /// so an event with no recent mouse report is attributed to the trackpad.
    private var lastReport: [String: UInt64] = [:]
    private var keyCache: [IOHIDDevice: String] = [:]
    /// device key -> multiplier, for the front app. Trackpads use "trackpad".
    var scales: [String: Double] = [:]

    // MARK: auto-match calibration
    /// Bundle id of the real frontmost app (including Squeak itself).
    var front: String?
    private(set) var calibrating = false
    private(set) var calBundle: String?
    private(set) var calDevice: String?            // PointerDevice.id being calibrated
    private(set) var calKey: String?               // that device's source key
    /// 1 = target circle (no scaling), 2 = check circle (scaled by calF0). 3 = done, showing result.
    private(set) var calPhase = 0
    private(set) var calF0: Double = 1
    /// Raw (pre-scale) horizontal hand movement per phase, counted only while the app has the cursor locked.
    private(set) var calRaw: [Double] = [0, 0]
    private var lastLoc = CGPoint.zero

    func beginCalibration(bundle: String, device: String, key: String) {
        calBundle = bundle; calDevice = device; calKey = key; calRaw = [0, 0]; calPhase = 1; calibrating = true
        if !running { start() }
    }
    func startCheckCircle(multiplier: Double) { calF0 = multiplier; calRaw[1] = 0; calPhase = 2 }
    func redoPhase() { if calPhase >= 1 && calPhase <= 2 { calRaw[calPhase - 1] = 0 } }
    func endCalibration() {
        calibrating = false; calBundle = nil; calDevice = nil; calKey = nil; calPhase = 0; calRaw = [0, 0]
        update(scales: scales)
    }

    // MARK: permissions
    static var hasAccessibility: Bool { AXIsProcessTrusted() }
    static var hasInputMonitoring: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }
    /// Input Monitoring state when this process started; IOHIDManager only works after a relaunch once granted.
    static let inputMonitoringAtLaunch = hasInputMonitoring
    static var needsRelaunch: Bool { hasInputMonitoring && !inputMonitoringAtLaunch }
    static var askedAt: [String: Date] = [:]

    static func requestAccessibility() {
        askedAt["ax"] = Date()
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openPane("Privacy_Accessibility")
    }
    static func requestInputMonitoring() {
        askedAt["im"] = Date()
        if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) { openPane("Privacy_ListenEvent") }
    }
    static func openPane(_ anchor: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }
    /// Reopens Squeak after this process has fully exited (opening while it's still quitting is silently ignored).
    static func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; sleep 0.3; /usr/bin/open \"\(Bundle.main.bundlePath)\""]
        p.standardOutput = nil; p.standardError = nil
        try? p.run()
        NSApp.terminate(nil)
    }
    static var ready: Bool { demo || (hasAccessibility && hasInputMonitoring && !needsRelaunch) }
    /// README screenshot mode (see DevTools): pretend setup is done.
    static let demo = ProcessInfo.processInfo.environment["SQUEAK_DEMO"] != nil && CommandLine.arguments.contains("--snapshot")

    // MARK: lifecycle
    func update(scales new: [String: Double]) {
        scales = new
        let needed = calibrating || (!new.isEmpty && new.values.contains { $0 != 1 })
        if needed && !running { start() } else if !needed && running { stop() }
        else if running && manager == nil && Self.hasInputMonitoring { startHID() }
    }

    private func start() {
        guard Self.hasAccessibility else { return }
        let mask: CGEventMask = [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: { _, type, event, ref in
            let s = Unmanaged<Scaler>.fromOpaque(ref!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = s.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            s.scale(event)
            return Unmanaged.passUnretained(event)
        }, userInfo: me) else { return }
        tap = t
        tapSource = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        startHID()
        running = true
    }

    private func stop() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false); CFMachPortInvalidate(t) }
        if let s = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        tap = nil; tapSource = nil
        if let m = manager { IOHIDManagerUnscheduleFromRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue); IOHIDManagerClose(m, 0) }
        manager = nil; keyCache = [:]; lastReport = [:]
        running = false
    }

    private func startHID() {
        guard Self.hasInputMonitoring else { return }
        let m = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatchingMultiple(m, [
            [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2],
            [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 1],
        ] as CFArray)
        IOHIDManagerSetInputValueMatchingMultiple(m, [
            [kIOHIDElementUsagePageKey: 1, kIOHIDElementUsageKey: 0x30],
            [kIOHIDElementUsagePageKey: 1, kIOHIDElementUsageKey: 0x31],
        ] as CFArray)
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(m, { ref, _, _, value in
            let s = Unmanaged<Scaler>.fromOpaque(ref!).takeUnretainedValue()
            guard IOHIDValueGetIntegerValue(value) != 0 else { return }
            let dev = IOHIDElementGetDevice(IOHIDValueGetElement(value))
            let key = s.keyCache[dev] ?? {
                func p(_ k: String) -> Any? { IOHIDDeviceGetProperty(dev, k as CFString) }
                let k = "\(p(kIOHIDVendorIDKey) as? Int ?? 0):\(p(kIOHIDProductIDKey) as? Int ?? 0):\(p(kIOHIDProductKey) as? String ?? "")"
                s.keyCache[dev] = k; return k
            }()
            s.lastReport[key] = mach_absolute_time()
        }, me)
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(m, 0)
        manager = m
    }

    // MARK: hot path
    private static let window: UInt64 = {   // 60 ms in mach ticks
        var tb = mach_timebase_info_data_t(); mach_timebase_info(&tb)
        return 60_000_000 * UInt64(tb.denom) / UInt64(tb.numer)
    }()

    /// Which device produced this event: the most recent mouse with a raw report inside the window, else the trackpad.
    func sourceKey() -> String {
        let now = mach_absolute_time()
        var best: (String, UInt64)?
        for (k, t) in lastReport where now &- t < Self.window && (best == nil || t > best!.1) { best = (k, t) }
        return best?.0 ?? "trackpad"
    }

    private func scale(_ e: CGEvent) {
        let key = sourceKey()
        if calibrating {
            // Count only camera turning: the app has locked the cursor, so its position stays put while deltas flow.
            let loc = e.location
            let locked = abs(loc.x - lastLoc.x) < 0.5 && abs(loc.y - lastLoc.y) < 0.5
            lastLoc = loc
            if front == calBundle, key == calKey, locked, calPhase == 1 || calPhase == 2 {
                calRaw[calPhase - 1] += e.getDoubleValueField(.mouseEventDeltaX)
            }
            if key == calKey {
                let f = calPhase == 2 ? calF0 : 1   // phase 1 = untouched; phase 2 = the multiplier under test
                if f != 1 { mul(e, f) }
                return
            }
        }
        let f = scales[key] ?? 1
        guard f != 1 else { return }
        mul(e, f)
    }

    private func mul(_ e: CGEvent, _ f: Double) {
        let dx = e.getDoubleValueField(.mouseEventDeltaX), dy = e.getDoubleValueField(.mouseEventDeltaY)
        e.setDoubleValueField(.mouseEventDeltaX, value: dx * f)
        e.setDoubleValueField(.mouseEventDeltaY, value: dy * f)
    }
}
