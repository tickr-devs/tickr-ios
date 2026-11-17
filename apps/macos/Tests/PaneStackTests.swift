import CoreGraphics
import Testing
import TickrDesign
@testable import TickrMac

@Suite("The Mac chart's panes share the card's height (mockup v103)")
struct PaneStackTests {
  @Test("Study panes are fixed; the price pane fills the rest, clamped to its least and most")
  func priceFillsTheRest() {
    let pane = Tokens.Chart.studyPaneHeight
    let axis = Tokens.Chart.timeAxisHeight
    // Room for more: the price pane stops at its most.
    #expect(PaneStack.priceHeight(available: 900, studies: 2) == Tokens.Chart.priceMaxHeight)
    // Between: it takes exactly what the panes and the time axis leave.
    #expect(PaneStack.priceHeight(available: 400 + 2 * pane + axis, studies: 2) == 400)
    // Short: never below its least.
    #expect(PaneStack.priceHeight(available: 200, studies: 5) == Tokens.Chart.priceMinHeight)
  }

  @Test("The stack asks for the panes' sum, never more than offered while that fits")
  func heightFits() {
    let pane = Tokens.Chart.studyPaneHeight
    let axis = Tokens.Chart.timeAxisHeight
    // Volume and the four indicators on, in a card of 494 points (the 26-point overflow before).
    let offered: CGFloat = 494
    let height = PaneStack.height(available: offered, studies: 5)
    #expect(height <= offered)
    #expect(height == PaneStack.priceHeight(available: offered, studies: 5) + 5 * pane + axis)
    // The default panes (volume, RSI) in a tall card: 420 for the price.
    #expect(PaneStack.height(available: nil, studies: 2) == Tokens.Chart.priceMaxHeight + 2 * pane + axis)
  }
}
