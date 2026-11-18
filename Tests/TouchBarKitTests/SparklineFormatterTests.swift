import Testing
@testable import TouchBarKit

@Suite("SparklineFormatter")
struct SparklineFormatterTests {
    @Test("Empty input produces no points")
    func emptyInputProducesNoPoints() {
        #expect(SparklineFormatter.normalizedPoints([]) == [])
    }

    @Test("A single value normalizes to the flat middle, not a division-by-zero crash")
    func singleValueIsFlatMiddle() {
        #expect(SparklineFormatter.normalizedPoints([42]) == [0.5])
    }

    @Test("All-equal values normalize to a flat middle line, not NaN")
    func allEqualValuesAreFlatMiddle() {
        #expect(SparklineFormatter.normalizedPoints([7, 7, 7]) == [0.5, 0.5, 0.5])
    }

    @Test("Distinct values map the minimum to 0, the maximum to 1, and others proportionally between")
    func distinctValuesNormalizeByMinMax() {
        #expect(SparklineFormatter.normalizedPoints([0, 50, 100]) == [0.0, 0.5, 1.0])
    }

    @Test("Output preserves input order")
    func outputPreservesInputOrder() {
        #expect(SparklineFormatter.normalizedPoints([100, 0, 50]) == [1.0, 0.0, 0.5])
    }
}
