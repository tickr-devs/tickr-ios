import Testing
@testable import TickrDesign

@Suite struct ListCapTests {
  @Test("A card shows at least the card's number of rows, the rest behind Show all")
  func leastRows() {
    // Eight fills of 20 points, 8 apart, in a card that hugs them (space = the least height).
    let heights: [Double?] = Array(repeating: 20, count: 8)
    let hugging = ListCap(heights: heights, available: 132, spacing: 8, limit: 5)
    #expect(hugging.shown == 5)
    #expect(hugging.hidden == 3)
    #expect(hugging.leastHeight == 132)
    #expect(hugging.fullHeight == 216)
    // Before anything is measured: the card's number, never more than there are.
    #expect(ListCap(heights: [nil, nil, nil], available: 0, spacing: 8, limit: 5).shown == 3)
    #expect(ListCap(heights: [], available: 400, spacing: 8, limit: 5).shown == 0)
  }

  @Test("A taller card (a large window) shows as many more rows as fit, never fewer than the least")
  func tallerCardShowsMore() {
    let heights: [Double?] = Array(repeating: 20, count: 8)
    #expect(ListCap(heights: heights, available: 188, spacing: 8, limit: 5).shown == 7)
    // Exactly every row's height, give or take rounding: every row, no Show all.
    let full = ListCap(heights: heights, available: 215.8, spacing: 8, limit: 5)
    #expect(full.shown == 8)
    #expect(full.hidden == 0)
    // A space smaller than the least (never laid out so) still shows the least.
    #expect(ListCap(heights: heights, available: 40, spacing: 8, limit: 5).shown == 5)
    // Unmeasured rows count as the tallest measured one.
    #expect(ListCap(heights: [20, 30, nil, nil], available: 70, spacing: 8, limit: 1).shown == 2)
  }
}
