import Dispatch
import os
import SystemKit

/// One `DispatchSourceTimer` for the whole app. Every sampler is decimated against this single
/// base tick rather than owning its own timer — PLAN.md §4.1, "one timer, not fifteen".
///
/// Also carries §4.2's adaptive-rate rules that don't need AppKit to express: on-battery halving
/// (`PowerSourceReader`, polled cheaply against the base tick rather than its own timer) and
/// per-sampler boost while its dropdown is open. The two rules that *do* need AppKit —
/// `NSWorkspace` sleep/wake and screen notifications — stay out of this type on purpose (§3.2:
/// "Never import AppKit into SystemKit", and by the same logic, keep it out of MetricsCore too);
/// `pause()`/`resume()` below are the seam the app target hooks those into.
public final class Scheduler: @unchecked Sendable {
    public static let baseInterval: Duration = .milliseconds(250)
    /// Battery state changes on plug/unplug, not continuously — polling every tick would just be
    /// another wakeup source for a fact that changes a few times a day at most.
    private static let powerCheckTicks = 120 // 120 × 250ms = 30s

    private struct Entry {
        /// The rate from `register`/`updateInterval` — i.e. Settings' "Update every", independent
        /// of anything below. `tick()` derives the *effective* rate from this each fire.
        var configuredIntervalTicks: Int
        /// §4.2: "Dropdown open — full rate, for that module only." Set via `setBoost`.
        var boosted: Bool
        var ticksSinceLastFire: Int
        /// A sample that has been started and hasn't finished. `tick()` won't start another for the
        /// same sampler until it clears, so a slow one (a busy `ps`, a stalled IOKit call) can't
        /// pile up overlapping samples that each hold a thread and then all deliver at once.
        var inFlight = false
        /// The last sample threw. Only used to log the transition, not every failure.
        var failing = false
        /// Distinguishes this registration from an earlier one of the same sampler, so a sample
        /// still in flight from before an `unregister` can't clear the new registration's state.
        let generation: Int
        /// Starts one sample; the closure passed in is called (from any thread) when it finishes,
        /// with the error if it threw.
        let fire: (@escaping @Sendable (Error?) -> Void) -> Void
    }

    private static let log = Logger(subsystem: "com.vitals.app", category: "Scheduler")

    private let queue = DispatchQueue(label: "vitals.scheduler")
    private var timer: DispatchSourceTimer?
    private var entries: [SamplerID: Entry] = [:]
    private var onBatteryPower = false
    private var ticksSincePowerCheck = 0
    private var suspended = false
    private var nextGeneration = 0

    public init() {}

    /// Registers a sampler's fire closure at its own cadence, decimated against the base tick.
    public func register<S: Sampler>(_ sampler: S, onSample: @escaping @Sendable (S.Output) -> Void) {
        let ticks = max(1, Int((sampler.defaultInterval / Scheduler.baseInterval).rounded()))
        queue.async {
            self.nextGeneration += 1
            self.entries[sampler.id] = Entry(
                configuredIntervalTicks: ticks, boosted: false, ticksSinceLastFire: ticks,
                generation: self.nextGeneration
            ) { finished in
                Task {
                    do {
                        onSample(try await sampler.sample())
                        finished(nil)
                    } catch {
                        finished(error)
                    }
                }
            }
        }
    }

    /// Stops a sampler firing and drops its cadence/boost state — the counterpart to `register`,
    /// for a module switched off in Settings. Registering it again later starts it fresh.
    public func unregister(_ id: SamplerID) {
        queue.async {
            self.entries[id] = nil
        }
    }

    /// A plain manual override of a registered sampler's fire rate — Settings' "Update every"
    /// control. Independent of, and composes with, `setBoost` and on-battery halving below: this
    /// sets the *configured* rate those two scale from, not the effective one.
    public func updateInterval(_ id: SamplerID, to interval: Duration) {
        let ticks = max(1, Int((interval / Scheduler.baseInterval).rounded()))
        queue.async {
            self.entries[id]?.configuredIntervalTicks = ticks
        }
    }

    /// §4.2: "Dropdown open — full rate — up to 4 Hz, for that module only." The base tick already
    /// runs at 4 Hz, so "full rate" just means firing on every tick instead of decimating — no
    /// separate boosted-rate constant needed. Coordinators call this from their popup's
    /// `onVisibilityChange`, so a sampler nobody is looking at drops back to its configured (or
    /// battery-halved) rate the instant the dropdown closes.
    public func setBoost(_ id: SamplerID, active: Bool) {
        queue.async {
            self.entries[id]?.boosted = active
        }
    }

    public func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(250), leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    /// Synchronous by design — a caller that immediately deallocates `self` after `stop()` needs
    /// the timer already torn down, not merely enqueued to tear down later. `queue.sync` is safe
    /// here (never called from `queue` itself — `tick()`, `pause()`, `resume()` etc. all run on
    /// it, `stop()` doesn't) and closes what was otherwise the one place touching `timer`/
    /// `suspended` outside `queue`'s serialization that everything else goes through.
    public func stop() {
        queue.sync {
            if suspended { timer?.resume(); suspended = false } // never cancel a suspended source
            timer?.cancel()
            timer = nil
        }
    }

    /// §4.2's "System sleep"/"display asleep" rows: nothing samples until `resume()`, including a
    /// sampler an alert depends on — §4.2 wanted those to keep running at a slower rate, which is
    /// not built, so an alert cannot fire while the display is asleep.
    /// The app target calls this from `NSWorkspace.willSleepNotification`
    /// /`screensDidSleepNotification` — `Scheduler` itself stays AppKit-free.
    public func pause() {
        queue.async {
            guard !self.suspended else { return }
            self.timer?.suspend()
            self.suspended = true
        }
    }

    /// Counterpart to `pause()`, called from `didWakeNotification`/`screensDidWakeNotification`.
    /// Each module's sampler already computes its rate from actual elapsed wall time
    /// (`ContinuousClock`, which keeps advancing through sleep) or from a tick-ratio that is
    /// naturally zero-weighted during sleep (CPU) — so the first post-wake sample is a correct
    /// average over the sleep gap, not a spike, and needs no separate "discard it" step.
    public func resume() {
        queue.async {
            guard self.suspended else { return }
            self.timer?.resume()
            self.suspended = false
        }
    }

    private func sampleFinished(_ id: SamplerID, generation: Int, error: Error?) {
        queue.async {
            guard self.entries[id]?.generation == generation else { return }
            self.entries[id]?.inFlight = false
            let wasFailing = self.entries[id]?.failing ?? false
            if let error {
                if !wasFailing { Scheduler.log.error("\(id.raw, privacy: .public) sample failed: \(String(describing: error), privacy: .public)") }
                self.entries[id]?.failing = true
            } else if wasFailing {
                Scheduler.log.info("\(id.raw, privacy: .public) sampling recovered")
                self.entries[id]?.failing = false
            }
        }
    }

    private func tick() {
        ticksSincePowerCheck += 1
        if ticksSincePowerCheck >= Scheduler.powerCheckTicks {
            ticksSincePowerCheck = 0
            onBatteryPower = PowerSourceReader.isOnBatteryPower()
        }

        for (id, var entry) in entries {
            let effectiveTicks = entry.boosted
                ? 1
                : (onBatteryPower ? entry.configuredIntervalTicks * 2 : entry.configuredIntervalTicks)
            entry.ticksSinceLastFire += 1
            // While a sample is still running the counter keeps growing, so the next one starts on
            // the first tick after it finishes rather than waiting out a whole extra interval.
            if entry.ticksSinceLastFire >= effectiveTicks, !entry.inFlight {
                entry.ticksSinceLastFire = 0
                entry.inFlight = true
                let generation = entry.generation
                entry.fire { [weak self] error in self?.sampleFinished(id, generation: generation, error: error) }
            }
            entries[id] = entry
        }
    }
}

/// The slice of `Scheduler` a module's lifecycle needs, so that lifecycle can be unit-tested with a
/// recording fake instead of a real 4 Hz timer.
public protocol SampleScheduling: AnyObject {
    func register<S: Sampler>(_ sampler: S, onSample: @escaping @Sendable (S.Output) -> Void)
    func unregister(_ id: SamplerID)
    func updateInterval(_ id: SamplerID, to interval: Duration)
    func setBoost(_ id: SamplerID, active: Bool)
}

extension Scheduler: SampleScheduling {}
