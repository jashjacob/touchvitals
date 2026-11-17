import Testing
@testable import TouchBarKit

/// vitals PLAN.md §4.6: "every redraw forces AppKit to re-snapshot the item" — a widget must only
/// ask to redraw when its formatted value actually changed, never on every scheduler tick.
@Suite("RedrawGate")
struct RedrawGateTests {
    @Test("The first value a gate ever sees always needs a redraw")
    func firstValueRedraws() {
        var gate = RedrawGate()
        #expect(gate.shouldRedraw(for: "4.5 KB/s") == true)
    }

    @Test("The same value twice in a row does not redraw the second time")
    func unchangedValueDoesNotRedraw() {
        var gate = RedrawGate()
        _ = gate.shouldRedraw(for: "4.5 KB/s")
        #expect(gate.shouldRedraw(for: "4.5 KB/s") == false)
    }

    @Test("A changed value redraws, and settling back to the old value redraws again")
    func changedValueRedraws() {
        var gate = RedrawGate()
        _ = gate.shouldRedraw(for: "4.5 KB/s")
        #expect(gate.shouldRedraw(for: "9.0 KB/s") == true)
        #expect(gate.shouldRedraw(for: "9.0 KB/s") == false)
        #expect(gate.shouldRedraw(for: "4.5 KB/s") == true)
    }
}
