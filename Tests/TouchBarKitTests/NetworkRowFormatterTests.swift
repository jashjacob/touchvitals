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

    @Test("downText and upText are the same substrings format() combines, so coloring them separately can't drift from the combined text")
    func downAndUpTextComposeIntoFormat() {
        let down = NetworkRowFormatter.downText(downBytesPerSec: 2048)
        let up = NetworkRowFormatter.upText(upBytesPerSec: 512)
        #expect(down == "↓ 2.0 KB/s")
        #expect(up == "↑ 512 B/s")
        #expect(NetworkRowFormatter.format(downBytesPerSec: 2048, upBytesPerSec: 512) == "\(down)  \(up)")
    }
}
