import IOKit.ps

/// Just enough of §5.7's eventual `SystemKit/Power` module to answer one question — is this Mac
/// currently running on battery — for §4.2's on-battery rate halving. Not a stand-in for item
/// 4.6's full battery module (charge %, cycle count, `AppleRawMaxCapacity`); that's real work of
/// its own, scoped separately.
public enum PowerSourceReader {
    /// `IOPSCopyPowerSourcesInfo`/`IOPSCopyPowerSourcesList` are the same unprivileged IOKit power
    /// API `pmset -g batt` is built on — no root, no entitlement, works on both a MacBook running
    /// on battery and a desktop Mac with no battery at all (returns `false` for the latter, since
    /// it has no source ever reporting `kIOPSBatteryPowerValue`).
    public static func isOnBatteryPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let state = description[kIOPSPowerSourceStateKey] as? String
            else { continue }
            if state == kIOPSBatteryPowerValue { return true }
        }
        return false
    }
}
