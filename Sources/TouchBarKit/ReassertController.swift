import Foundation

/// The slice of real scheduling `ReassertController` needs, so its debounce/coalescing decisions
/// can be unit-tested with a recording fake instead of real `DispatchQueue` timing.
public protocol ReassertScheduling: AnyObject {
    func scheduleReassert(after delay: TimeInterval, _ action: @escaping () -> Void)
    func cancelPendingReassert()
}

/// TokenBar's `scheduleReassert()`/`menuTrackingBegan`/`menuTrackingEnded` pattern, extracted so
/// the decision of *when* to ask for a reassert is separate from *how* AppKit actually re-presents
/// the bar. TokenBar's own comment on this debounce: "without it you'll thrash on every app
/// switch" — `appActivated()` fires on every `NSWorkspace.didActivateApplicationNotification`,
/// which can arrive in quick bursts.
public final class ReassertController {
    private let scheduler: ReassertScheduling
    private let debounce: TimeInterval
    private let reassert: () -> Void

    public init(scheduler: ReassertScheduling, debounce: TimeInterval, reassert: @escaping () -> Void = {}) {
        self.scheduler = scheduler
        self.debounce = debounce
        self.reassert = reassert
    }

    /// Call on `NSWorkspace.didActivateApplicationNotification`.
    public func appActivated() {
        schedule()
    }

    /// Call on the HIToolbox `beginMenuTrackingNotification` — a Dock menu takes the Touch Bar
    /// without activating an app, so this is the one case `appActivated()` alone wouldn't catch,
    /// and reasserting while the menu is still open would fight the user mid-interaction.
    public func menuTrackingBegan() {
        scheduler.cancelPendingReassert()
    }

    /// Call on the HIToolbox `endMenuTrackingNotification`.
    public func menuTrackingEnded() {
        schedule()
    }

    private func schedule() {
        scheduler.cancelPendingReassert()
        scheduler.scheduleReassert(after: debounce) { [reassert] in reassert() }
    }
}
