import CoreWLAN
import Foundation

/// Raw, monotonic per-interface counters. No delta math, no state — see PLAN.md §3.3:
/// `SystemKit` readers are stateless, `Modules` samplers hold the previous reading.
public struct InterfaceCounters: Sendable, Equatable {
    public let name: String
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let isUp: Bool
}

public struct WiFiStatus: Sendable, Equatable {
    public let ssid: String?
    public let rssi: Int
    public let transmitRateMbps: Double
}

/// Everything one `getifaddrs` walk yields: the per-interface counters and each interface's IPv4
/// address. A sampler that needs both (and the primary interface picked from the first) takes one
/// snapshot per sample instead of walking the interface list once per question.
public struct NetworkSnapshot: Sendable, Equatable {
    public let counters: [InterfaceCounters]
    /// The first `AF_INET` address of each interface that has one.
    public let ipv4ByInterface: [String: String]
}

public enum NetworkInterfaceReader {
    /// One `getifaddrs` walk: sums the AF_LINK entries per interface name (PLAN.md §5.5) and picks
    /// up the address off each interface's separate `AF_INET` entry.
    public static func readSnapshot() -> NetworkSnapshot {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else {
            return NetworkSnapshot(counters: [], ipv4ByInterface: [:])
        }
        defer { freeifaddrs(first) }

        var byName: [String: (in: UInt64, out: UInt64, up: Bool)] = [:]
        var ipv4: [String: String] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let addr = ptr {
            defer { ptr = addr.pointee.ifa_next }
            let family = addr.pointee.ifa_addr.pointee.sa_family
            if family == UInt8(AF_LINK) {
                guard let data = addr.pointee.ifa_data else { continue }
                let flags = Int32(addr.pointee.ifa_flags)
                let name = String(cString: addr.pointee.ifa_name)
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                var entry = byName[name] ?? (in: 0, out: 0, up: (flags & IFF_UP) != 0)
                entry.in += UInt64(ifData.ifi_ibytes)
                entry.out += UInt64(ifData.ifi_obytes)
                entry.up = (flags & IFF_UP) != 0
                byName[name] = entry
            } else if family == UInt8(AF_INET) {
                let name = String(cString: addr.pointee.ifa_name)
                guard ipv4[name] == nil, let address = ipv4String(addr.pointee.ifa_addr) else { continue }
                ipv4[name] = address
            }
        }
        let counters = byName.map {
            InterfaceCounters(name: $0.key, bytesIn: $0.value.in, bytesOut: $0.value.out, isUp: $0.value.up)
        }
        return NetworkSnapshot(counters: counters, ipv4ByInterface: ipv4)
    }

    /// Real negotiated Wi-Fi rate — never derived from `ifi_baudrate`. PLAN.md §5.5.
    public static func readWiFiStatus(interfaceName: String) -> WiFiStatus? {
        guard let interface = CWWiFiClient.shared().interface(withName: interfaceName) else { return nil }
        return WiFiStatus(
            ssid: interface.ssid(),
            rssi: interface.rssiValue(),
            transmitRateMbps: interface.transmitRate()
        )
    }

    private static func ipv4String(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        var storage = sockaddr_in()
        withUnsafeMutableBytes(of: &storage) { dest in
            dest.copyMemory(from: UnsafeRawBufferPointer(
                start: address,
                count: MemoryLayout<sockaddr_in>.size
            ))
        }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &storage.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /// The `en*`/`pdp_ip*` interface actually carrying traffic, picked by byte volume rather than
    /// interface name or dictionary iteration order (both are unstable — `en1`..`en4` exist and
    /// sit at 0 bytes on most Macs, so "first en* that's up" silently flips interface at random).
    public static func primaryInterfaceName(in counters: [InterfaceCounters]) -> String? {
        counters
            .filter { $0.isUp && $0.name != "lo0" && ($0.name.hasPrefix("en") || $0.name.hasPrefix("pdp_ip")) }
            .max { ($0.bytesIn + $0.bytesOut) < ($1.bytesIn + $1.bytesOut) }?
            .name
    }
}
