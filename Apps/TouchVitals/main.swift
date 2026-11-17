import AppKit
import AppMain
import Foundation
import MetricsCore
import Modules
import TouchBarKit

// Phase 3: wire TouchBarController's persistence — the expanded bar now re-asserts itself after
// switching apps or closing a Dock menu, instead of only showing once at launch. Verify on real
// hardware: switch to Safari, Finder, and open a Dock menu — does the bar reappear within ~200ms?

setvbuf(stdout, nil, _IONBF, 0)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let scheduler = Scheduler()
    private let networkSampler = NetworkSampler()
    private let diskSampler = DiskSampler()
    private let expandedBarView = ExpandedBarView()
    private lazy var touchBarController = TouchBarController(contentView: expandedBarView)

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

        touchBarController.start()
        scheduler.start()
        print("touchvitals Phase 3 running — expanded bar persists across app switches and Dock menus.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.stop()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
