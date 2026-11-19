import CoreGraphics
import Testing
@testable import TickrDesign

@MainActor @Suite struct ScrollPageTests {
  /// The phone's Home tab (iPhone 18 Pro): a 716 pt container between insets of 62 and 96.
  private let insetTop: CGFloat = 62
  private let container: CGFloat = 716

  @Test("A page is counted from the content's top below the top inset, not from the raw offset")
  func pageCountsFromShownTop() {
    let page = ScrollPage()
    // At the top the content's top sits at -insetTop: nothing scrolled yet.
    page.follow(offset: -insetTop, insetTop: insetTop, content: 3000, container: container)
    #expect(page.shown == 0)
    #expect(page.next == .offset(container * Tokens.Scroll.pageShare))
  }

  @Test("With no more than a page left, a tap goes to the very bottom (owner, 2026-11-19)")
  func shortRestGoesToBottom() {
    let page = ScrollPage()
    // The owner's Home: a little more than the screen, 150 pt below the visible area.
    page.follow(offset: -insetTop, insetTop: insetTop, content: container + 150, container: container)
    #expect(page.next == .bottom)
    // Just short of the end (the old stop, one inset away): the next tap still moves to the bottom.
    page.follow(offset: 150 - insetTop - insetTop, insetTop: insetTop, content: container + 150,
      container: container)
    #expect(page.next == .bottom)
  }

  @Test("The Mac (no insets): pages until the rest fits, then the bottom")
  func macPagesThenBottom() {
    let page = ScrollPage()
    page.follow(offset: 0, insetTop: 0, content: 2000, container: 500)
    #expect(page.next == .offset(400))
    page.follow(offset: 1200, insetTop: 0, content: 2000, container: 500)
    #expect(page.next == .bottom)
  }
}
