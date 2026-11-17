import AppKit
import Foundation
import MetricsCore
import Modules
import PrivateTouchBar
import TouchBarKit

// Phase 2: build the NSCustomTouchBarItem content (network + disk row) and show it once via
// PrivateTouchBar.present() at launch. No persistence yet — re-asserting across app switches and
// Dock menus is Phase 3. Verify on real hardware: does the expanded bar show both widgets, and do
// they update as you'd expect against Activity Monitor?

setvbuf(stdout, nil, _IONBF, 0)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let scheduler = Scheduler()
    private let networkSampler = NetworkSampler()
    private let diskSampler = DiskSampler()
    private let expandedBarView = ExpandedBarView()
    private var touchBar: NSTouchBar?

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler.register(networkSampler) { [weak self] rate in
            let down = ByteRateFormatter.format(bytesPerSecond: rate.downBytesPerSec)
            let up = ByteRateFormatter.format(bytesPerSecond: rate.upBytesPerSec)
            print("[net]  \(rate.interfaceName ?? "-")  down \(down)  up \(up)")
            DispatchQueue.main.async {
                self?.expandedBarView.updateNetwork(downBytesPerSec: rate.downBytesPerSec, upBytesPerSec: rate.upBytesPerSec)
            }
        }

        scheduler.register(diskSampler) { [weak self] stats in
            guard let primary = stats.volumes.first(where: { $0.bsdName == stats.primaryBSDName }) else { return }
            print("[disk] \(primary.volumeName)  \(primary.availableBytes) B free of \(primary.totalBytes) B")
            DispatchQueue.main.async {
                self?.expandedBarView.updateDisk(totalBytes: primary.totalBytes, availableBytes: primary.availableBytes)
            }
        }

        presentExpandedBar()
        scheduler.start()
        print("touchvitals Phase 2 running — expanded bar presented once at launch, no persistence yet.")
    }

    private func presentExpandedBar() {
        let item = NSCustomTouchBarItem(identifier: .init("com.jashjacob.TouchVitals.expanded"))
        item.view = expandedBarView
        let bar = NSTouchBar()
        bar.templateItems = [item]
        bar.defaultItemIdentifiers = [item.identifier]
        touchBar = bar
        PrivateTouchBar.present(bar)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
