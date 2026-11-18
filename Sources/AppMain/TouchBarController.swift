import AppKit
import PrivateTouchBar
import TouchBarKit

/// Adapted from TokenBar's TouchBarController, stripped of all chip/banner/reset logic — just the
/// bar lifecycle and the persistence/reassert wiring. The debounce *decision* logic lives in
/// ReassertController (tested); this class is the untestable-by-design AppKit glue around it:
/// installing the collapse hook, observing NSWorkspace and HIToolbox menu-tracking notifications,
/// and actually calling PrivateTouchBar.present()/dismiss().
///
/// Depends on these private symbols (via PrivateTouchBar): DFRElementSetControlStripPresenceForIdentifier,
/// NSTouchBarItem.addSystemTrayItem:/removeSystemTrayItem:, NSTouchBar.presentSystemModalTouchBar:
/// systemTrayItemIdentifier:/dismissSystemModalTouchBar:/minimizeSystemModalTouchBar:. All are
/// dlopen'd/dlsym'd or resolved via responds(to:), logging instead of crashing if a future macOS
/// removes them — see PrivateTouchBar.swift.
@MainActor
public final class TouchBarController: NSObject {
    private let contentView: NSView
    private var bar: NSTouchBar?
    private var stripItem: NSCustomTouchBarItem?
    private var started = false
    private lazy var reassertController = ReassertController(
        scheduler: DispatchReassertScheduler(),
        debounce: 0.2,
        reassert: { [weak self] in self?.presentExpanded() }
    )

    public init(contentView: NSView) {
        self.contentView = contentView
        super.init()
    }

    public func start() {
        guard !started else { return }
        started = true
        PrivateTouchBar.installCollapseHook()
        PrivateTouchBar.onExternalCollapse = { [weak self] in
            self?.bar = nil
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        watchMenuTracking()
        installStrip()
        presentExpanded()
    }

    public func stop() {
        guard started else { return }
        started = false
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        PrivateTouchBar.onExternalCollapse = nil
        if let bar {
            PrivateTouchBar.dismiss(bar)
        }
        self.bar = nil
        if let stripItem {
            PrivateTouchBar.removeStripItem(stripItem)
        }
        stripItem = nil
    }

    /// presentSystemModalTouchBar:systemTrayItemIdentifier: has no Control Strip item registered
    /// for stripIdentifier to anchor to without this — it renders nothing, with no crash and no
    /// logged error. TokenBar's own TouchBarController.start() always calls installStrip() before
    /// presentExpanded() for the same reason; this is required for Phase 3, not a Phase 4 extra.
    private func installStrip() {
        guard stripItem == nil else { return }
        let item = NSCustomTouchBarItem(identifier: PrivateTouchBar.stripIdentifier)
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 30))
        button.title = "TV"
        button.imagePosition = .noImage
        button.isBordered = true
        button.bezelStyle = .rounded
        item.view = button
        stripItem = item
        PrivateTouchBar.addStripItem(item)
    }

    private func presentExpanded() {
        let item = NSCustomTouchBarItem(identifier: .init("com.jashjacob.TouchVitals.expanded"))
        item.view = contentView
        let bar = NSTouchBar()
        bar.templateItems = [item]
        bar.defaultItemIdentifiers = [item.identifier]
        self.bar = bar
        PrivateTouchBar.present(bar)
    }

    @objc private func appActivated() {
        reassertController.appActivated()
    }

    /// A Dock menu takes the Touch Bar without activating an app, so this registration has to be
    /// delivered anyway — same reasoning as TokenBar's own watchMenuTracking().
    private func watchMenuTracking() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self, selector: #selector(menuTrackingBegan),
            name: Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification"),
            object: nil, suspensionBehavior: .deliverImmediately
        )
        center.addObserver(
            self, selector: #selector(menuTrackingEnded),
            name: Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification"),
            object: nil, suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func menuTrackingBegan() {
        reassertController.menuTrackingBegan()
    }

    @objc private func menuTrackingEnded() {
        reassertController.menuTrackingEnded()
    }
}
