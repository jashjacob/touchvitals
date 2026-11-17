import Diagnostics
import MetricsCore
import SystemKit

public struct NetworkRate: Sendable, Equatable {
    public let interfaceName: String?
    public let localIPv4: String?
    public let downBytesPerSec: Double
    public let upBytesPerSec: Double
    /// The interface's own raw counters (§5.5) — cumulative since it came up, not since this app
    /// launched. Passed straight through rather than accumulated from rates, which would drift by
    /// however much rounding a `rate × interval` sum introduces over a long-running session.
    public let totalBytesIn: UInt64
    public let totalBytesOut: UInt64
    public let wifi: WiFiStatus?
}

/// Holds the previous raw counters so it can emit a rate — PLAN.md §3.3: "a sampler holds its
/// previous raw reading... that state is why samplers are instances, not free functions."
public actor NetworkSampler: Sampler {
    public nonisolated let id = SamplerID("network")
    public nonisolated let defaultInterval: Duration = .seconds(1)

    private var previous: (counters: InterfaceCounters, at: ContinuousClock.Instant)?
    private var lastGoodRates: (down: Double, up: Double)?
    private let clock = ContinuousClock()

    // §4.2's dropdown-open boost samples this actor up to 4x/sec — the same regression CPU hit
    // (PLAN.md item 1.2's note) with `host_statistics`, confirmed here too via a NetDebug check:
    // under *continuous real traffic*, `getifaddrs`'s interface byte counters can still return
    // byte-identical values across a full 250ms poll — the kernel's own refresh is coarser than
    // that. Unlike CPU's percentages, a genuine 0 B/s is common and expected for network (a link
    // really does go quiet), so simply coasting on the last rate forever would be wrong the other
    // way — an idle link would get stuck showing a stale nonzero rate. Below this window, an
    // unchanged counter is treated as "hasn't refreshed yet" (don't advance the baseline, so the
    // next real tick's rate is computed over the full combined gap, and surface the last real
    // rate meanwhile); at or above it, unchanged is trusted as real silence and settles to 0B/s
    // exactly as a fresh reading would. Comfortably above the ~250-500ms artifact window observed,
    // comfortably below `defaultInterval`'s normal 1s cadence so nothing changes there.
    private static let minReliableWindow: Duration = .milliseconds(750)

    public init() {}

    public func sample() async throws -> NetworkRate {
        let signpostState = Signposts.sampler.beginInterval("Network")
        defer { Signposts.sampler.endInterval("Network", signpostState) }
        // One `getifaddrs` walk serves the primary-interface pick, its counters and its address.
        let snapshot = NetworkInterfaceReader.readSnapshot()
        guard let name = NetworkInterfaceReader.primaryInterfaceName(in: snapshot.counters),
              let current = snapshot.counters.first(where: { $0.name == name }) else {
            previous = nil
            lastGoodRates = nil
            return NetworkRate(
                interfaceName: nil, localIPv4: nil, downBytesPerSec: 0, upBytesPerSec: 0,
                totalBytesIn: 0, totalBytesOut: 0, wifi: nil
            )
        }

        let wifi = NetworkInterfaceReader.readWiFiStatus(interfaceName: name)
        let localIPv4 = snapshot.ipv4ByInterface[name]
        let now = clock.now

        guard let prev = previous, prev.counters.name == name, current.bytesIn >= prev.counters.bytesIn,
              current.bytesOut >= prev.counters.bytesOut else {
            previous = (current, now)
            // `(0, 0)`, not `nil` — this establishes a fresh baseline (dropdown just opened, or
            // the interface just changed), and 0 B/s is the correct thing to show until a real
            // delta exists. Seeding it here, rather than leaving it `nil` until the first real
            // computation below sets it, means the very next tick's zero-delta check (line ~73)
            // can already use the window-extension path instead of falling through to a possibly
            // premature "real" 0 B/s reading one tick sooner than necessary.
            lastGoodRates = (0, 0)
            return NetworkRate(
                interfaceName: name, localIPv4: localIPv4, downBytesPerSec: 0, upBytesPerSec: 0,
                totalBytesIn: current.bytesIn, totalBytesOut: current.bytesOut, wifi: wifi
            )
        }

        let elapsed = now - prev.at
        let unchanged = current.bytesIn == prev.counters.bytesIn && current.bytesOut == prev.counters.bytesOut
        if unchanged, elapsed < Self.minReliableWindow, let lastGoodRates {
            // Too soon to trust this as real silence. Deliberately does not update `previous` —
            // the next tick's window extends back to the last *real* reading, not this stale one.
            return NetworkRate(
                interfaceName: name, localIPv4: localIPv4,
                downBytesPerSec: lastGoodRates.down, upBytesPerSec: lastGoodRates.up,
                totalBytesIn: current.bytesIn, totalBytesOut: current.bytesOut, wifi: wifi
            )
        }

        defer { previous = (current, now) }
        let seconds = elapsed.rateWindowSeconds
        let down = Double(current.bytesIn - prev.counters.bytesIn) / seconds
        let up = Double(current.bytesOut - prev.counters.bytesOut) / seconds
        lastGoodRates = (down, up)
        return NetworkRate(
            interfaceName: name, localIPv4: localIPv4, downBytesPerSec: down, upBytesPerSec: up,
            totalBytesIn: current.bytesIn, totalBytesOut: current.bytesOut, wifi: wifi
        )
    }
}
