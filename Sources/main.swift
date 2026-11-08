import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let popover = NSPopover()
    let watcher = DeviceWatcher()
    var panel: PanelVC?

    func applicationDidFinishLaunching(_ n: Notification) {
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Squeak")
            b.target = self; b.action = #selector(toggle)
        }
        popover.behavior = .transient; popover.delegate = self
        let e = Engine.shared
        watcher.onChange = { [weak self] in
            e.connected = self?.watcher.devices ?? []
            e.apply(); self?.panel?.render()
        }
        watcher.start()
        e.connected = watcher.devices
        let ws = NSWorkspace.shared
        ws.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
            Scaler.shared.front = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            e.frontChanged(n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
        ws.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in e.reapplyForced() }
        Scaler.shared.front = ws.frontmostApplication?.bundleIdentifier
        e.frontChanged(ws.frontmostApplication)
        e.apply()
    }

    @objc func toggle() {
        if popover.isShown { popover.performClose(nil); return }
        Engine.shared.reapplyForced()   // picks up newly granted permissions
        let vc = PanelVC(); panel = vc
        popover.contentViewController = vc
        popover.show(relativeTo: item.button!.bounds, of: item.button!, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ n: Notification) { popover.contentViewController = nil; panel = nil }   // free the UI when hidden

    func applicationWillTerminate(_ n: Notification) { Engine.shared.flush(); Engine.shared.restoreOriginals() }
}

DevTools.runIfRequested()   // --snapshot / --icon / --social (used to make the README images); exits when handled
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
signal(SIGTERM) { _ in DispatchQueue.main.async { NSApp.terminate(nil) } }
app.run()
