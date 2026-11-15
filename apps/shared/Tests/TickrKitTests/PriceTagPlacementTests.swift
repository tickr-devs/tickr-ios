import Testing
@testable import TickrKit

@Suite("Where a price tag sits on the price scale")
struct PriceTagPlacementTests {
  /// A price area from 40 to 48 with tags half a dollar high on each side of their price.
  static let prices = 40.0...48.0
  static let half = 0.5

  @Test("A tag whose whole height fits stays at its price")
  func inside() {
    #expect(PriceTagPlacement.position(of: 44.2, in: Self.prices, halfHeight: Self.half) == 44.2)
    #expect(PriceTagPlacement.position(of: 40.5, in: Self.prices, halfHeight: Self.half) == 40.5)
    #expect(PriceTagPlacement.position(of: 47.5, in: Self.prices, halfHeight: Self.half) == 47.5)
  }

  @Test("A price below or above the area, or too near its edge, is pinned to that edge")
  func pinned() {
    #expect(PriceTagPlacement.position(of: 38.85, in: Self.prices, halfHeight: Self.half) == 40.5)
    #expect(PriceTagPlacement.position(of: 40.2, in: Self.prices, halfHeight: Self.half) == 40.5)
    #expect(PriceTagPlacement.position(of: 52, in: Self.prices, halfHeight: Self.half) == 47.5)
  }

  @Test("A tag taller than the whole area sits in its middle")
  func tooTall() {
    #expect(PriceTagPlacement.position(of: 38, in: 40.0...40.6, halfHeight: Self.half) == 40.3)
  }

  /// Rounds to cents so sums of binary fractions compare exactly.
  func cents(_ values: [Double]) -> [Double] {
    values.map { ($0 * 100).rounded() / 100 }
  }

  @Test("Tags a whole tag apart or more stay at their prices, in the order given")
  func apart() {
    let shown = PriceTagPlacement.positions(of: [46, 42, 44], in: Self.prices, halfHeight: Self.half)
    #expect(shown == [46, 42, 44])
  }

  @Test("Touching tags are pushed apart upward, the lowest keeping its place")
  func pushedApart() {
    // Entry 42.26 and stop 41.82 touch; the last price 38.85 is pinned to the bottom, 40.5.
    let shown = PriceTagPlacement.positions(of: [42.26, 41.82, 38.85], in: Self.prices, halfHeight: Self.half)
    #expect(cents(shown) == [42.82, 41.82, 40.5])
  }

  @Test("Tags pushed past the top are pushed back down from it")
  func backFromTheTop() {
    let shown = PriceTagPlacement.positions(of: [47.4, 47.6, 52], in: Self.prices, halfHeight: Self.half)
    #expect(cents(shown) == [45.5, 46.5, 47.5])
  }

  @Test("Tags that cannot all fit apart are spread evenly over the area")
  func tooMany() {
    let shown = PriceTagPlacement.positions(of: [44, 44.1, 44.2, 44.3, 44.4, 44.5, 44.6, 44.7, 44.8],
      in: Self.prices, halfHeight: Self.half)
    #expect(cents(shown) == [40.5, 41.38, 42.25, 43.13, 44, 44.88, 45.75, 46.63, 47.5])
  }
}
