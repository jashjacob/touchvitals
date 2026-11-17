import Foundation
import Testing
@testable import TouchBarKit

/// Records calls instead of actually waiting, so these tests verify the debounce/coalescing
/// *decisions* ReassertController makes without depending on real time passing.
private final class RecordingScheduler: ReassertScheduling {
    enum Call: Equatable {
        case scheduled(delay: TimeInterval)
        case cancelled
    }

    private(set) var calls: [Call] = []

    func scheduleReassert(after delay: TimeInterval, _ action: @escaping () -> Void) {
        calls.append(.scheduled(delay: delay))
    }

    func cancelPendingReassert() {
        calls.append(.cancelled)
    }
}

@Suite("ReassertController")
struct ReassertControllerTests {
    @Test("Activating another app cancels any pending reassert, then schedules a new one")
    func appActivatedCancelsThenSchedules() {
        let scheduler = RecordingScheduler()
        let controller = ReassertController(scheduler: scheduler, debounce: 0.2)
        controller.appActivated()
        #expect(scheduler.calls == [.cancelled, .scheduled(delay: 0.2)])
    }

    @Test("Two activations in a row each cancel-then-schedule — the coalescing TokenBar's own comment calls out as required to avoid thrashing")
    func repeatedActivationsAlwaysCancelFirst() {
        let scheduler = RecordingScheduler()
        let controller = ReassertController(scheduler: scheduler, debounce: 0.2)
        controller.appActivated()
        controller.appActivated()
        #expect(scheduler.calls == [
            .cancelled, .scheduled(delay: 0.2),
            .cancelled, .scheduled(delay: 0.2),
        ])
    }

    @Test("A Dock menu opening cancels any pending reassert and schedules nothing")
    func menuTrackingBeganOnlyCancels() {
        let scheduler = RecordingScheduler()
        let controller = ReassertController(scheduler: scheduler, debounce: 0.2)
        controller.menuTrackingBegan()
        #expect(scheduler.calls == [.cancelled])
    }

    @Test("A Dock menu closing schedules a reassert, the same as activating an app")
    func menuTrackingEndedSchedules() {
        let scheduler = RecordingScheduler()
        let controller = ReassertController(scheduler: scheduler, debounce: 0.2)
        controller.menuTrackingEnded()
        #expect(scheduler.calls == [.cancelled, .scheduled(delay: 0.2)])
    }

    @Test("A menu opening right after an activation was scheduled cancels that pending reassert")
    func menuOpeningCancelsAPendingActivationReassert() {
        let scheduler = RecordingScheduler()
        let controller = ReassertController(scheduler: scheduler, debounce: 0.2)
        controller.appActivated()
        controller.menuTrackingBegan()
        #expect(scheduler.calls == [.cancelled, .scheduled(delay: 0.2), .cancelled])
    }
}
