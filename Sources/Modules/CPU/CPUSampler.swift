import Diagnostics
import Foundation
import MetricsCore
import SystemKit

public struct CPUUsage: Sendable, Equatable {
    public let overallPercent: Double
    /// User, system and idle sum to 100 (nice folded into user — this Mac has no workloads that
    /// set it, and a fourth number nobody reads is not worth a fourth row).
    public let userPercent: Double
    public let systemPercent: Double
    public let idlePercent: Double
    public let perCorePercent: [Double]
    public let load1: Double
    public let load5: Double
    public let load15: Double
    public let uptimeSeconds: TimeInterval
    /// False on the very first sample, which has no previous tick snapshot to diff against.
    ///
    /// The percentages are zero in that case, and that zero is **not a reading** — it means "not
    /// measured yet", which §6.6 says must never be rendered as a value. Callers show the
    /// no-data-yet state instead of plotting it. Load averages and uptime are absolute readings
    /// and are valid either way.
    public let hasBaseline: Bool
}

/// Holds the previous raw ticks to diff against — PLAN.md §3.3. Delta math uses `&-` wrapping
/// subtraction on `UInt32` per §5.1; a plain subtraction would spike negative whenever a tick
/// counter wraps.
public actor CPUSampler: Sampler {
    public nonisolated let id = SamplerID("cpu")
    public nonisolated let defaultInterval: Duration = .seconds(1)

    private var previousAggregate: RawCPUTicks?
    private var previousPerCore: [RawCPUTicks]?

    // §4.2's dropdown-open boost samples this actor up to 4x/sec — faster than
    // `host_statistics(HOST_CPU_LOAD_INFO)` (the API behind the aggregate Total/User/System/Idle
    // breakdown) turns out to actually refresh. Confirmed empirically via a NetDebug check at the
    // boosted 250ms cadence: consecutive polls can return byte-identical tick counts (a zero
    // total delta), then "catch up" a large delta on whichever poll follows once the kernel's own
    // counter finally updates. A zero total delta does not mean 0% usage — it means this
    // particular tick has no new information yet, and `percent`/`breakdown` below return `nil`
    // for exactly that reason rather than a fake zero.
    //
    // The fix is to coast on the last real reading until the next one arrives, the same "never
    // render a missing reading as a value" rule `hasBaseline` already applies to the very first
    // sample (§6.6) — not to publish whatever the degenerate math would otherwise produce. Kept
    // per-core, indexed independently, since one core hitting this refresh gap on a given tick
    // doesn't mean every core did.
    private var lastGoodOverall: Double = 0
    private var lastGoodBreakdown: (user: Double, system: Double, idle: Double) = (0, 0, 0)
    private var lastGoodPerCore: [Double] = []

    public init() {}

    public func sample() async throws -> CPUUsage {
        let signpostState = Signposts.sampler.beginInterval("CPU")
        defer { Signposts.sampler.endInterval("CPU", signpostState) }
        let aggregate = CPULoadReader.readAggregateTicks()
        let perCore = CPULoadReader.readPerCoreTicks()
        defer {
            previousAggregate = aggregate
            previousPerCore = perCore
        }

        let hasBaseline = previousAggregate != nil

        if let previous = previousAggregate, let overall = Self.percent(from: previous, to: aggregate) {
            lastGoodOverall = overall
        }
        if let previous = previousAggregate, let breakdown = Self.breakdown(from: previous, to: aggregate) {
            lastGoodBreakdown = breakdown
        }
        updateLastGoodPerCore(from: previousPerCore, to: perCore)

        let loads = CPULoadReader.loadAverages()
        return CPUUsage(
            overallPercent: lastGoodOverall,
            userPercent: lastGoodBreakdown.user,
            systemPercent: lastGoodBreakdown.system,
            idlePercent: lastGoodBreakdown.idle,
            perCorePercent: lastGoodPerCore,
            load1: loads.one,
            load5: loads.five,
            load15: loads.fifteen,
            uptimeSeconds: CPULoadReader.uptime(),
            hasBaseline: hasBaseline
        )
    }

    private func updateLastGoodPerCore(from previous: [RawCPUTicks]?, to current: [RawCPUTicks]) {
        guard let previous, previous.count == current.count else {
            lastGoodPerCore = Array(repeating: 0, count: current.count)
            return
        }
        if lastGoodPerCore.count != current.count {
            lastGoodPerCore = Array(repeating: 0, count: current.count)
        }
        for index in current.indices {
            if let corePercent = Self.percent(from: previous[index], to: current[index]) {
                lastGoodPerCore[index] = corePercent
            }
            // else: this core's counter hasn't refreshed since the last tick — leave its entry at
            // whatever `lastGoodPerCore[index]` already holds rather than dropping it to zero.
        }
    }

    /// `nil` means "no new tick data this interval" (a zero total delta), not "0% usage" — see
    /// this type's own note above on why that distinction matters at a boosted sample rate.
    private static func percent(from previous: RawCPUTicks, to current: RawCPUTicks) -> Double? {
        let user = current.user &- previous.user
        let system = current.system &- previous.system
        let nice = current.nice &- previous.nice
        let idle = current.idle &- previous.idle

        let inUse = UInt64(user) + UInt64(system) + UInt64(nice)
        let total = inUse + UInt64(idle)
        guard total != 0 else { return nil }
        return min(1, Double(inUse) / Double(total)) * 100
    }

    /// Same delta math as `percent(from:to:)`, split three ways instead of collapsed to one
    /// number, and the same `nil`-means-"no new data" contract. `user + system + idle` reproduces
    /// `percent(from:to:)` (nice folds into user in both places), so the two never disagree.
    private static func breakdown(
        from previous: RawCPUTicks,
        to current: RawCPUTicks
    ) -> (user: Double, system: Double, idle: Double)? {
        let user = current.user &- previous.user
        let system = current.system &- previous.system
        let nice = current.nice &- previous.nice
        let idle = current.idle &- previous.idle

        let total = UInt64(user) + UInt64(system) + UInt64(nice) + UInt64(idle)
        guard total != 0 else { return nil }
        return (
            user: Double(UInt64(user) + UInt64(nice)) / Double(total) * 100,
            system: Double(system) / Double(total) * 100,
            idle: Double(idle) / Double(total) * 100
        )
    }
}
