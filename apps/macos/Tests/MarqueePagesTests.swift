import CoreGraphics
import Testing
@testable import TickrScreens

@Suite("Screener chips row: pages of the endless row")
struct MarqueePagesTests {
  @Test("A page holds enough chips at their least width to span the strip")
  func spansStrip() {
    let pages = MarqueePages(stripWidth: 1000, leastChipWidth: 104)
    #expect(pages.size == 10)
    #expect(CGFloat(pages.size) * 104 >= 1000)
    #expect(pages.slots(from: 20) == 20..<30)
  }

  @Test("At least one chip on a page, also before the strip is laid out")
  func neverEmpty() {
    #expect(MarqueePages(stripWidth: 0, leastChipWidth: 104).size == 1)
    #expect(MarqueePages(stripWidth: 500, leastChipWidth: 0).size == 1)
  }
}
