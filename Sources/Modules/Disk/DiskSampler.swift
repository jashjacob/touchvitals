import Diagnostics
import Foundation
import MetricsCore
import SystemKit

public struct DiskStats: Sendable, Equatable {
    public let volumes: [VolumeInfo]
    /// `nil` only if the boot volume's own I/O counters couldn't be resolved at all — the volume
    /// list above is independent of this and still populates normally in that case.
    public let primaryBSDName: String?
    public let readBytesPerSec: Double
    public let writeBytesPerSec: Double
    /// The primary volume's own raw counters (§5.4) — cumulative since boot, not since this app
    /// launched. Same reasoning as `NetworkRate.totalBytesIn`: passed straight through rather than
    /// accumulated from rates, which would drift.
    public let totalBytesRead: UInt64
    public let totalBytesWritten: UInt64
}

/// Holds the previous raw counters so it can emit a rate — same shape as `NetworkSampler`.
public actor DiskSampler: Sampler {
    public nonisolated let id = SamplerID("disk")
    public nonisolated let defaultInterval: Duration = .seconds(2)

    private var previous: (counters: DiskActivityCounters, at: ContinuousClock.Instant)?
    private let clock = ContinuousClock()
    /// Enumerating volumes is the expensive part of a tick (~20ms of CPU, all of it CacheDelete's
    /// purgeable-space query — profiled at roughly 1% of a core at this sampler's 2s interval), and
    /// what it returns barely changes: free space drifts slowly and volumes rarely come and go. So
    /// the list is kept, re-read every `volumeRefreshInterval`, and immediately whenever the set of
    /// mounted volumes changes (checked every tick, and cheap) — a plugged-in or ejected drive
    /// still shows up on the next sample.
    static let volumeRefreshInterval: Duration = .seconds(30)
    private var cachedVolumes: (volumes: [VolumeInfo], mounted: Set<URL>, at: ContinuousClock.Instant)?

    public init() {}

    /// The boot volume's BSD name (a `DASession` plus resolving `/`) can only change if the set of
    /// mounted volumes does, so it is resolved once per mounted-set instead of every tick. A
    /// failed resolve is not cached and is retried on the next tick.
    private var cachedPrimaryBSDName: (name: String, mounted: Set<URL>)?

    private func currentVolumes() -> (volumes: [VolumeInfo], mounted: Set<URL>) {
        let mounted = Set(DiskReader.mountedVolumeURLs())
        let now = clock.now
        if let cachedVolumes, cachedVolumes.mounted == mounted, now - cachedVolumes.at < Self.volumeRefreshInterval {
            return (cachedVolumes.volumes, mounted)
        }
        let volumes = DiskReader.enumerateVolumes()
        cachedVolumes = (volumes, mounted, now)
        return (volumes, mounted)
    }

    private func primaryBSDName(mounted: Set<URL>) -> String? {
        if let cachedPrimaryBSDName, cachedPrimaryBSDName.mounted == mounted { return cachedPrimaryBSDName.name }
        guard let name = DiskReader.primaryVolumeBSDName() else {
            cachedPrimaryBSDName = nil
            return nil
        }
        cachedPrimaryBSDName = (name, mounted)
        return name
    }

    public func sample() async throws -> DiskStats {
        let signpostState = Signposts.sampler.beginInterval("Disk")
        defer { Signposts.sampler.endInterval("Disk", signpostState) }
        let (volumes, mounted) = currentVolumes()

        guard let bsdName = primaryBSDName(mounted: mounted),
              let current = DiskReader.readActivity(bsdName: bsdName)
        else {
            previous = nil
            return DiskStats(
                volumes: volumes, primaryBSDName: nil, readBytesPerSec: 0, writeBytesPerSec: 0,
                totalBytesRead: 0, totalBytesWritten: 0
            )
        }

        let now = clock.now
        defer { previous = (current, now) }

        guard let prev = previous, prev.counters.bsdName == current.bsdName,
              current.bytesRead >= prev.counters.bytesRead, current.bytesWritten >= prev.counters.bytesWritten
        else {
            return DiskStats(
                volumes: volumes, primaryBSDName: bsdName, readBytesPerSec: 0, writeBytesPerSec: 0,
                totalBytesRead: current.bytesRead, totalBytesWritten: current.bytesWritten
            )
        }

        let elapsed = now - prev.at
        let seconds = elapsed.rateWindowSeconds
        let read = Double(current.bytesRead - prev.counters.bytesRead) / seconds
        let write = Double(current.bytesWritten - prev.counters.bytesWritten) / seconds
        return DiskStats(
            volumes: volumes, primaryBSDName: bsdName, readBytesPerSec: read, writeBytesPerSec: write,
            totalBytesRead: current.bytesRead, totalBytesWritten: current.bytesWritten
        )
    }
}
