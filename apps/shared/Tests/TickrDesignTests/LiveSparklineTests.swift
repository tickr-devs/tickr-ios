import CoreGraphics
import Testing
@testable import TickrDesign

// The layer view is a view: main-actor.
@MainActor @Suite struct LiveSparklineTests {
  @Test("The line shows its last points and spans them; a flat line sits mid-height")
  func windowAndSpan() {
    let values = (0..<20).map(Double.init)
    #expect(LiveSparkline.window(values, .small) == Array(values.suffix(Tokens.Sparkline.gapsSmall + 1)))
    #expect(LiveSparkline.window(values, .large).count == Tokens.Sparkline.gapsLarge + 1)
    #expect(LiveSparkline.window([5], .small) == [5, 5])
    #expect(LiveSparkline.span([38.06, 38.4, 38.02]) == 38.02...38.4)
    let flat = LiveSparkline.span([12.5, 12.5])
    #expect(flat.upperBound - 12.5 == 12.5 - flat.lowerBound)
  }

  @Test("Points are right-aligned, evenly apart, and always as many, so two lines morph")
  func points() {
    let size = CGSize(width: 90, height: 30)
    let points = LiveSparkView.points([1, 2, 3], domain: 1...3, gaps: 9, size: size)
    #expect(points.count == 10)
    #expect(points.last == CGPoint(x: 90, y: 0))
    #expect(points[8] == CGPoint(x: 80, y: 15))
    #expect(points[7] == CGPoint(x: 70, y: 30))
    // The short line repeats its first point to the left.
    #expect(points[0] == points[7])
  }

  @Test("A new price moves only the last point; a closed bar starts the new point at the old end")
  func glideStarts() {
    let size = CGSize(width: 90, height: 30)
    let before = LiveSparkLayer(shown: [1, 2, 3], total: 3, domain: 0...4, live: true, scale: .small, still: false)
    let tick = LiveSparkLayer(shown: [1, 2, 4], total: 3, domain: 0...4, live: true, scale: .small, still: false)
    let drawn = LiveSparkView.points(before.shown, domain: before.domain, gaps: 9, size: size)
    #expect(LiveSparkView.from(before, to: tick, size: size) == drawn)
    let bar = LiveSparkLayer(shown: [1, 2, 3, 3.5], total: 4, domain: 0...4, live: true, scale: .small,
      still: false)
    let from = LiveSparkView.from(before, to: bar, size: size)
    #expect(from.count == 10)
    #expect(Array(from.suffix(4)) == Array(drawn.suffix(3)) + [drawn[9]])
  }
}
