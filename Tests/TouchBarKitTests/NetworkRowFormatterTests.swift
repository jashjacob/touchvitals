import Testing
@testable import TouchBarKit

@Suite("NetworkRowFormatter")
struct NetworkRowFormatterTests {
    @Test("Zero down and a 1 KB/s up rate shows both arrows with their own units")
    func zeroDownSomeUp() {
        #expect(NetworkRowFormatter.format(downBytesPerSec: 0, upBytesPerSec: 1024) == "↓ 0 B/s  ↑ 1.0 KB/s")
    }

    @Test("A 1 MB/s down rate and zero up rate")
    func highDownZeroUp() {
        #expect(NetworkRowFormatter.format(downBytesPerSec: 1_048_576, upBytesPerSec: 0) == "↓ 1.0 MB/s  ↑ 0 B/s")
    }

    @Test("Down always comes before up, even when up is the larger number")
    func downBeforeUpRegardlessOfMagnitude() {
        let row = NetworkRowFormatter.format(downBytesPerSec: 10, upBytesPerSec: 1_048_576)
        #expect(row.hasPrefix("↓"))
        #expect(row.contains("↑ 1.0 MB/s"))
    }
}
