import Foundation

/// Where the price chart's round markers go (trade entries and exits, the open position's entry,
/// the strategy's watch, entry and refused marks): only those that fit whole in the stretch on
/// screen, and a marker that would cover another one drawn before it is moved by whole marker
/// steps toward the middle of the pane (up in its lower half, down in its upper half) until it
/// covers none, so a stack never runs off the pane. A marker before or after the stretch on screen, or so near its
/// edge that the plot would cut it, is not drawn at all, so it never piles up at the edge.
public enum ChartMarkerLayout {
  /// One marker as the chart would draw it before any lifting.
  public struct Marker<ID: Hashable & Sendable>: Hashable, Sendable {
    public let id: ID
    public let time: Date
    public let price: Double
    /// A marker that states a price (a trade's entry or exit, the open position's entry): placed
    /// before every other marker, so it stays on its price and the others move out of its way.
    public let pinned: Bool

    public init(id: ID, time: Date, price: Double, pinned: Bool = false) {
      self.id = id
      self.time = time
      self.price = price
      self.pinned = pinned
    }
  }

  /// How the plot maps time and price to points, and how big a marker is.
  public struct Scale: Hashable, Sendable {
    /// The stretch of time on screen.
    public let shown: ClosedRange<Date>
    /// The prices from the bottom to the top of the pane.
    public let prices: ClosedRange<Double>
    /// Points of plot width per second.
    public let pointsPerSecond: Double
    /// Points of plot height per unit of price.
    public let pointsPerPrice: Double
    /// A marker's side, in points: two markers closer than this on both axes overlap.
    public let side: Double
    /// How far one step moves a marker, in points.
    public let step: Double

    public init(
      shown: ClosedRange<Date>, prices: ClosedRange<Double>, pointsPerSecond: Double, pointsPerPrice: Double,
      side: Double, step: Double
    ) {
      self.shown = shown
      self.prices = prices
      self.pointsPerSecond = pointsPerSecond
      self.pointsPerPrice = pointsPerPrice
      self.side = side
      self.step = step
    }
  }

  /// How far each marker on screen is moved, in steps, by its id: 0 where it belongs, positive
  /// up, negative down. A marker missing from the result does not fit whole in the stretch on
  /// screen and is not drawn. Pinned markers are placed first, then the others; within each,
  /// oldest first, and equal times keep the order given.
  public static func place<ID>(_ markers: [Marker<ID>], scale: Scale) -> [ID: Int] {
    // Half a marker in time: a centre closer than this to either edge would be cut.
    let half = scale.pointsPerSecond > 0 ? scale.side / 2 / scale.pointsPerSecond : 0
    let first = scale.shown.lowerBound.addingTimeInterval(half)
    let last = scale.shown.upperBound.addingTimeInterval(-half)
    let visible = markers.enumerated()
      .filter { first <= $0.element.time && $0.element.time <= last }
      .sorted {
        // false < true would put pinned last: compare "not pinned" so pinned come first.
        (!$0.element.pinned ? 1 : 0, $0.element.time, $0.offset) < (!$1.element.pinned ? 1 : 0, $1.element.time, $1.offset)
      }
      .map(\.element)
    var placed: [(x: Double, y: Double)] = []
    var lifts: [ID: Int] = [:]
    let middle = (scale.prices.lowerBound + scale.prices.upperBound) / 2
    for marker in visible {
      let x = marker.time.timeIntervalSince(scale.shown.lowerBound) * scale.pointsPerSecond
      // Screen points grow downward: a higher price sits higher, at a smaller y.
      let y = -marker.price * scale.pointsPerPrice
      let direction = marker.price > middle ? -1 : 1
      var lift = 0
      // A step of zero could never move a marker clear, so it is left where it belongs.
      while scale.step > 0, placed.contains(where: { covers($0, (x, y - Double(lift) * scale.step), scale.side) }) {
        lift += direction
      }
      placed.append((x, y - Double(lift) * scale.step))
      lifts[marker.id] = lift
    }
    return lifts
  }

  /// Whether two markers' centres are closer than a side on both axes.
  private static func covers(_ one: (x: Double, y: Double), _ other: (x: Double, y: Double), _ side: Double) -> Bool {
    abs(one.x - other.x) < side && abs(one.y - other.y) < side
  }
}
