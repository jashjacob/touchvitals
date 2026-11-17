import AppKit

/// Phase 0 spike: does DFRElementSetControlStripPresenceForIdentifier /
/// addSystemTrayItem still resolve and register a permanent Control Strip icon
/// on this exact macOS version? No expanded bar, no persistence/reassert logic —
/// that's Phase 3. Just: does the icon show up, and does it survive switching
/// between other apps.
final class SpikeDelegate: NSObject, NSApplicationDelegate {
    private var stripItem: NSCustomTouchBarItem?
    private var stripView: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStrip()
    }

    private func installStrip() {
        let item = NSCustomTouchBarItem(identifier: PrivateTouchBar.stripIdentifier)
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 30))
        button.title = "TV"
        button.imagePosition = .noImage
        button.isBordered = true
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.isEnabled = true
        item.view = button
        stripItem = item
        stripView = button
        PrivateTouchBar.addStripItem(item)
        Log.line("spike: control strip item installed (\(PrivateTouchBar.stripIdentifier.rawValue))")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = SpikeDelegate()
app.delegate = delegate
Log.line("spike: launching")
app.run()
