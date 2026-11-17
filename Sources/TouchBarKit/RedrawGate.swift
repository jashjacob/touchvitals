/// PLAN.md §4.6 (vitals): "every redraw forces AppKit to re-snapshot the item" — a Touch Bar
/// widget must only redraw when its formatted display value actually changed, never on every
/// scheduler tick. This gate is the one place that decision gets made, so it can't silently regress
/// to "always redraw" without a test noticing.
public struct RedrawGate {
    private var lastRendered: String?

    public init() {}

    /// Returns whether `value` differs from the last value this gate saw, and records it either
    /// way so the next call compares against `value`.
    public mutating func shouldRedraw(for value: String) -> Bool {
        guard value != lastRendered else { return false }
        lastRendered = value
        return true
    }
}
