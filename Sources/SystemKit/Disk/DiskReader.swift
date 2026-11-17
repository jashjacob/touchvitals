import DiskArbitration
import Foundation
import IOKit

/// One mounted, visible volume — PLAN.md §5.4. Enumerated via DiskArbitration rather than
/// `statfs`, which gives stable identity (BSD name) and metadata `statfs` doesn't: file system
/// kind, a real volume name.
public struct VolumeInfo: Sendable, Equatable, Identifiable {
    public let bsdName: String
    public let volumeName: String
    public let fileSystemKind: String
    public let isInternal: Bool
    public let totalBytes: UInt64
    public let availableBytes: UInt64
    public var id: String { bsdName }

    public init(
        bsdName: String, volumeName: String, fileSystemKind: String,
        isInternal: Bool, totalBytes: UInt64, availableBytes: UInt64
    ) {
        self.bsdName = bsdName
        self.volumeName = volumeName
        self.fileSystemKind = fileSystemKind
        self.isInternal = isInternal
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }
}

/// Raw, monotonic per-volume I/O counters — no delta math, no state, matching
/// `InterfaceCounters`'s split (§3.3: readers are stateless, samplers hold the previous reading).
public struct DiskActivityCounters: Sendable, Equatable {
    public let bsdName: String
    public let bytesRead: UInt64
    public let bytesWritten: UInt64

    public init(bsdName: String, bytesRead: UInt64, bytesWritten: UInt64) {
        self.bsdName = bsdName
        self.bytesRead = bytesRead
        self.bytesWritten = bytesWritten
    }
}

public enum DiskReader {
    /// Just which volumes are mounted right now — no capacity, name or type. Cheap (~0.02ms), unlike
    /// `enumerateVolumes()` (~20ms of CPU, because reading a volume's available space goes through
    /// CacheDelete's purgeable-space query), so a caller can poll this every tick and only pay for
    /// the full enumeration when the answer changes.
    public static func mountedVolumeURLs() -> [URL] {
        FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
    }

    /// Every mounted, non-hidden volume — Time Machine backup volumes, hidden system volumes,
    /// etc. are exactly what `.skipHiddenVolumes` exists to exclude, per §5.4's own DiskArbitration
    /// approach.
    public static func enumerateVolumes() -> [VolumeInfo] {
        let session = DASessionCreate(kCFAllocatorDefault)
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsInternalKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url -> VolumeInfo? in
            guard let session, let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
                  let bsdNamePointer = DADiskGetBSDName(disk)
            else { return nil }
            let bsdName = String(cString: bsdNamePointer)

            let description = DADiskCopyDescription(disk) as? [String: Any] ?? [:]
            let fileSystemKind = description[kDADiskDescriptionVolumeKindKey as String] as? String ?? "Unknown"

            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return VolumeInfo(
                bsdName: bsdName,
                volumeName: values.volumeName ?? url.lastPathComponent,
                fileSystemKind: fileSystemKind,
                isInternal: values.volumeIsInternal ?? false,
                totalBytes: UInt64(max(values.volumeTotalCapacity ?? 0, 0)),
                availableBytes: UInt64(max(values.volumeAvailableCapacityForImportantUsage ?? 0, 0))
            )
        }
    }

    /// The boot volume's own BSD name, resolved the same way any other volume's is — matching
    /// `NetworkInterfaceReader.primaryInterfaceName()`'s naming, this is the one this module picks
    /// automatically for its I/O chart absent any manual selection.
    public static func primaryVolumeBSDName() -> String? {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, URL(fileURLWithPath: "/") as CFURL),
              let pointer = DADiskGetBSDName(disk)
        else { return nil }
        return String(cString: pointer)
    }

    /// Walks from a volume's own BSD name up the IOKit registry to whichever ancestor actually
    /// publishes byte counters — §5.4's exact keys, `"Bytes (Read)"`/`"Bytes (Write)"`, spaces and
    /// parentheses included.
    ///
    /// A volume's *own* node (its literal BSD name, e.g. an APFS volume slice) is not that
    /// ancestor: on Apple Silicon it instead publishes a filesystem-level `Statistics` dictionary
    /// (AuthAPFS validation counts, VNOP call counts) that happens to share the same property
    /// name but has none of the expected keys. The real byte counters live one or more levels up
    /// — the APFS container, or the physical device — so this walks past any `Statistics` dict
    /// that lacks `"Bytes (Read)"` rather than stopping at the first one found, verified against
    /// this machine's actual registry tree before writing this.
    ///
    /// Never caches the resolved `io_service_t` across calls — §5.4's own warning ("volumes get
    /// remounted and a cached handle then reports another drive's numbers") is a staleness bug
    /// that resolving fresh on every call cannot have, by construction.
    public static func readActivity(bsdName: String) -> DiskActivityCounters? {
        guard let matching = IOBSDNameMatching(kIOMainPortDefault, 0, bsdName) else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var current = service
        var depth = 0
        while depth < 10 {
            if let property = IORegistryEntryCreateCFProperty(current, "Statistics" as CFString, kCFAllocatorDefault, 0) {
                let dict = property.takeRetainedValue() as? [String: Any]
                if let bytesRead = dict?["Bytes (Read)"] as? Int64, let bytesWritten = dict?["Bytes (Write)"] as? Int64 {
                    if current != service { IOObjectRelease(current) }
                    return DiskActivityCounters(
                        bsdName: bsdName, bytesRead: UInt64(max(bytesRead, 0)), bytesWritten: UInt64(max(bytesWritten, 0))
                    )
                }
            }
            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            if current != service { IOObjectRelease(current) }
            guard result == KERN_SUCCESS, parent != 0 else { return nil }
            current = parent
            depth += 1
        }
        return nil
    }
}
