import Darwin

/// PLAN.md §5.3 values are `1 = normal`, `2 = warning`, `4 = critical` — switch on 2 and 4
/// explicitly; a `> 1` comparison is wrong because 2 and 4 aren't ordered that way for a bitmask
/// reading, they're just the three values the kernel happens to report.
public enum MemoryPressureLevel: Int, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4
    case unknown = 0
}

public struct MemoryStats: Sendable, Equatable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let swapUsedBytes: UInt64
    public let swapTotalBytes: UInt64
    public let pressureLevel: MemoryPressureLevel
}

/// Fully stateless — unlike CPU/Network, `vm_statistics64` gives point-in-time page counts, not
/// monotonic counters, so there's nothing to diff and no reason for this to be an actor.
public enum MemoryReader {
    /// PLAN.md §5.3 — "the formula that matters": seven terms, two subtracted. `inactive` counts
    /// as used; `purgeable` and `external` (file-backed) come back out. Get this wrong and the
    /// numbers disagree with Activity Monitor forever, for no obvious reason.
    public static func read() -> MemoryStats {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryStats(totalBytes: 0, usedBytes: 0, freeBytes: 0, wiredBytes: 0, compressedBytes: 0, swapUsedBytes: 0, swapTotalBytes: 0, pressureLevel: .unknown)
        }

        let pageSize = hostConstants.pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let external = UInt64(stats.external_page_count) * pageSize

        let used = active + inactive + speculative + wired + compressed - purgeable - external
        let total = hostConstants.totalBytes
        let free = total > used ? total - used : 0
        let swap = swapUsage()

        return MemoryStats(
            totalBytes: total,
            usedBytes: used,
            freeBytes: free,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            pressureLevel: pressureLevel()
        )
    }

    /// Physical memory and page size cannot change while the process runs, so they are read once
    /// (two Mach calls) instead of on every sample.
    private static let hostConstants: (pageSize: UInt64, totalBytes: UInt64) = {
        var rawPageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &rawPageSize)

        var info = host_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_info(mach_host_self(), HOST_BASIC_INFO, intPointer, &count)
            }
        }
        return (UInt64(rawPageSize), result == KERN_SUCCESS ? info.max_mem : 0)
    }()

    private static func pressureLevel() -> MemoryPressureLevel {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .unknown }
        return MemoryPressureLevel(rawValue: Int(level)) ?? .unknown
    }

    private static func swapUsage() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return (0, 0) }
        return (usage.xsu_used, usage.xsu_total)
    }
}
