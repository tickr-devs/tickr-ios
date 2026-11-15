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
  func cents(_ values: [Double?]) -> [Double?] {
    values.map { $0.map { ($0 * 100).rounded() / 100 } }
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

  @Test("How many tags fit a whole tag apart: at least one, at most all")
  func room() {
    #expect(PriceTagPlacement.room(for: 9, in: Self.prices, halfHeight: Self.half) == 8)
    #expect(PriceTagPlacement.room(for: 3, in: Self.prices, halfHeight: Self.half) == 3)
    #expect(PriceTagPlacement.room(for: 3, in: 40.0...42.0, halfHeight: Self.half) == 2)
    #expect(PriceTagPlacement.room(for: 3, in: 40.0...40.6, halfHeight: Self.half) == 1)
    #expect(PriceTagPlacement.room(for: 0, in: Self.prices, halfHeight: Self.half) == 0)
  }

  @Test("Tags that cannot all fit apart: the most important ones that fit are kept, the rest dropped")
  func tooMany() {
    let shown = PriceTagPlacement.positions(of: [44, 44.1, 44.2, 44.3, 44.4, 44.5, 44.6, 44.7, 44.8],
      in: Self.prices, halfHeight: Self.half)
    #expect(cents(shown) == [40.5, 41.5, 42.5, 43.5, 44.5, 45.5, 46.5, 47.5, nil])
  }

  @Test("An area shorter than one tag shows only the first tag, in its middle")
  func tinyArea() {
    let shown = PriceTagPlacement.positions(of: [44, 41, 40.3], in: 40.0...40.6, halfHeight: Self.half)
    #expect(cents(shown) == [40.3, nil, nil])
  }

  @Test("Tags at the same price get distinct places when they fit, else the later one is dropped")
  func samePrice() {
    let two = PriceTagPlacement.positions(of: [41, 41, 41], in: 40.0...42.0, halfHeight: Self.half)
    #expect(cents(two) == [40.5, 41.5, nil])
  }

  @Test("Placed tags never share a place and never overlap, however short the area")
  func alwaysDistinct() {
    let prices = [44.0, 44.0, 41.82, 42.26, 38.85, 52]
    for tenths in 0...100 {
      let area = 40.0...(40.0 + Double(tenths) / 10)
      let placed = PriceTagPlacement.positions(of: prices, in: area, halfHeight: Self.half).compactMap { $0 }
      #expect(!placed.isEmpty)
      let sorted = placed.sorted()
      for (low, high) in zip(sorted, sorted.dropFirst()) {
        #expect(high - low >= 2 * Self.half - 1e-9)
      }
    }
  }
}
