import Testing
@testable import TickrDesign

@Suite struct ScrollEdgesTests {
  private func edges(above: Bool, below: Bool) -> ScrollEdges {
    var edges = ScrollEdges()
    edges.above = above
    edges.below = below
    return edges
  }

  @Test("At the end, content growing under it keeps the scroll at the end (owner, 2026-11-20)")
  func followsGrowthAtTheEnd() {
    #expect(ScrollEdges.keepsEnd(old: edges(above: true, below: false), new: edges(above: true, below: true), idle: true))
  }

  @Test("A person scrolling up from the end is not pulled back")
  func notWhileScrolling() {
    #expect(!ScrollEdges.keepsEnd(old: edges(above: true, below: false), new: edges(above: true, below: true), idle: false))
  }

  @Test("At the top (never scrolled), growth leaves the top in view and shows the chevron")
  func notAtTheTop() {
    #expect(!ScrollEdges.keepsEnd(old: edges(above: false, below: false), new: edges(above: false, below: true), idle: true))
  }

  @Test("Content shorter than the frame (no scroll yet) grows past it: the top stays in view")
  func notWhenItFitted() {
    #expect(!ScrollEdges.keepsEnd(old: edges(above: false, below: false), new: edges(above: false, below: true), idle: true))
  }

  @Test("Away from the end nothing moves")
  func notInTheMiddle() {
    #expect(!ScrollEdges.keepsEnd(old: edges(above: true, below: true), new: edges(above: true, below: true), idle: true))
  }
}
