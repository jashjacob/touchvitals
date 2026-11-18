import Foundation

/// Raw, monotonic tick counters for one core. No delta math here — PLAN.md §3.3: `SystemKit`
/// readers are stateless, the `Modules` sampler holds the previous reading.
public struct RawCPUTicks: Sendable, Equatable {
    public let user: UInt32
    public let system: UInt32
    public let nice: UInt32
    public let idle: UInt32
}

public enum CPULoadReader {
    /// PLAN.md §5.1. Copies ticks into plain `UInt32`s and frees the mach buffer before
    /// returning, every call — rather than the reference's carry-the-raw-buffer-one-cycle
    /// approach, this satisfies "free the previous buffer every cycle" trivially, since there is
    /// never a buffer left un-freed between calls.
    public static func readPerCoreTicks() -> [RawCPUTicks] {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return [] }
        defer {
            let size = vm_size_t(MemoryLayout<integer_t>.stride * Int(numCpuInfo))
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: UnsafeRawPointer(info))), size)
        }

        var ticks: [RawCPUTicks] = []
        ticks.reserveCapacity(Int(numCPUsU))
        for i in 0..<Int32(numCPUsU) {
            let base = Int(CPU_STATE_MAX * i)
            ticks.append(RawCPUTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            ))
        }
        return ticks
    }

    /// PLAN.md §5.1's "aggregate-only alternative" — cheaper than summing `readPerCoreTicks()`
    /// when only an overall percentage is needed. Index order per `<mach/machine.h>`:
    /// `CPU_STATE_USER=0, SYSTEM=1, IDLE=2, NICE=3`.
    public static func readAggregateTicks() -> RawCPUTicks {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return RawCPUTicks(user: 0, system: 0, nice: 0, idle: 0) }
        return RawCPUTicks(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            nice: info.cpu_ticks.3,
            idle: info.cpu_ticks.2
        )
    }

    public static func loadAverages() -> (one: Double, five: Double, fifteen: Double) {
        var avg = [Double](repeating: 0, count: 3)
        getloadavg(&avg, 3)
        return (avg[0], avg[1], avg[2])
    }

    public static func uptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 else { return 0 }
        let bootInterval = TimeInterval(boottime.tv_sec) + TimeInterval(boottime.tv_usec) / 1e6
        return Date().timeIntervalSince1970 - bootInterval
    }
}
