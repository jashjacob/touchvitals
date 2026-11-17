public struct SamplerID: Hashable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
}

public protocol Sampler: Sendable {
    associatedtype Output: Sendable
    var id: SamplerID { get }
    var defaultInterval: Duration { get }
    /// Called off the main actor. Must not block > ~10 ms.
    func sample() async throws -> Output
}
