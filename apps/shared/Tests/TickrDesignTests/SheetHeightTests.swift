import CoreGraphics
import Testing
@testable import TickrDesign

@Suite struct SheetHeightTests {
  @Test("A sheet grows by what its scroll view hides (owner, 2026-11-20: the bot actions)")
  func growsByOverflow() {
    // Half the iPhone's height, with the emergency stop and Cancel below the fold.
    #expect(SheetHeight.needed(sheet: 420, overflow: 180) == 600)
  }

  @Test("A sheet shrinks by what its scroll view leaves empty")
  func shrinksByEmptySpace() {
    #expect(SheetHeight.needed(sheet: 800, overflow: -350) == 450)
  }

  @Test("The height asked for does not depend on the sheet's current height: one pass fits")
  func fixedPoint() {
    // The same content (600) and chrome around the scroll view (40) at two sheet heights.
    let content: CGFloat = 600
    let chrome: CGFloat = 40
    let first = SheetHeight.needed(sheet: 420, overflow: content - (420 - chrome))
    let second = SheetHeight.needed(sheet: 640, overflow: content - (640 - chrome))
    #expect(first == second)
  }

  @Test("Before the scroll view or the sheet is measured, no height is asked for")
  func unmeasured() {
    #expect(SheetHeight.needed(sheet: 420, overflow: nil) == nil)
    #expect(SheetHeight.needed(sheet: 0, overflow: 100) == nil)
  }
}
