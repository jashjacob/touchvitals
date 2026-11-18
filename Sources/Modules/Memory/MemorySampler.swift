import Diagnostics
import MetricsCore
import SystemKit

/// No previous-reading state needed — `MemoryReader.read()` is already a complete point-in-time
/// computation, unlike CPU/Network's monotonic-counter diffing. A plain struct is enough; an
/// actor would just be ceremony here.
public struct MemorySampler: Sampler {
    public let id = SamplerID("memory")
    public let defaultInterval: Duration = .seconds(2)

    public init() {}

    public func sample() async throws -> MemoryStats {
        let signpostState = Signposts.sampler.beginInterval("Memory")
        defer { Signposts.sampler.endInterval("Memory", signpostState) }
        return MemoryReader.read()
    }
}
