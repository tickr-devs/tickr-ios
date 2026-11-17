import Testing
@testable import TickrDesign

@Suite struct FittingRowsTests {
  @Test("A card shows as many rows as fit its height, never a gap and never none")
  func fillsTheHeight() {
    // Four rows of 50 points, 8 apart: 50 + 58 + 58 = 166 fits 170, a fourth does not.
    #expect(RowFit.count([50, 50, 50, 50], available: 170, spacing: 8, fallback: 3) == 3)
    #expect(RowFit.count([50, 50, 50, 50, 50], available: 300, spacing: 8, fallback: 3) == 5)
    // A row not measured yet counts as the tallest measured one.
    #expect(RowFit.count([50, 60, nil, nil], available: 190, spacing: 8, fallback: 3) == 3)
    #expect(RowFit.count([50, 60, nil, nil], available: 185, spacing: 8, fallback: 3) == 2)
    // A taller row ends the run where it no longer fits.
    #expect(RowFit.count([50, 90, 50], available: 150, spacing: 8, fallback: 3) == 2)
    // At least one row, however small the card; none without rows.
    #expect(RowFit.count([80, 50], available: 40, spacing: 8, fallback: 3) == 1)
    #expect(RowFit.count([], available: 400, spacing: 8, fallback: 3) == 0)
    // Before the first measurement: the fallback, never more than there are.
    #expect(RowFit.count([nil, nil, nil, nil], available: 400, spacing: 8, fallback: 3) == 3)
    #expect(RowFit.count([50, 50, 50, 50], available: 0, spacing: 8, fallback: 4) == 4)
    #expect(RowFit.count([nil, nil], available: 0, spacing: 8, fallback: 3) == 2)
  }
}
