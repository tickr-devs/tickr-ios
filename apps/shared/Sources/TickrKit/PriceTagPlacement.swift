import Foundation

/// Where price tags (the last price, entries, stops) sit on the price pane's scale: each at its
/// price when the whole tag fits in the price area on screen, else pinned to the nearer edge of
/// that area, so a tag never hangs below the plot or over the volume bars; tags that would
/// touch are then pushed apart, still inside the area. When the area is too short for all of
/// them, only the most important tags that fit are kept, so every tag shown is readable and no
/// two share a place on the scale. A tag always reads its own price.
public enum PriceTagPlacement {
  /// The scale value to draw a tag for `price` at, given the prices from the bottom to the top
  /// of the price area (`prices`) and half a tag's height in price units (`halfHeight`). When a
  /// tag is taller than the whole area it sits in the area's middle.
  public static func position(of price: Double, in prices: ClosedRange<Double>, halfHeight: Double) -> Double {
    let lowest = prices.lowerBound + halfHeight
    let highest = prices.upperBound - halfHeight
    guard lowest <= highest else { return (prices.lowerBound + prices.upperBound) / 2 }
    return min(max(price, lowest), highest)
  }

  /// How many tags fit a whole tag apart in `area`: at least one, so the most important tag
  /// is always shown (in the area's middle when it is taller than the area), and at most `count`.
  public static func room(for count: Int, in area: ClosedRange<Double>, halfHeight: Double) -> Int {
    let height = halfHeight + halfHeight
    guard count > 1, height > 0 else { return min(count, 1) }
    let span = area.upperBound - area.lowerBound - height
    guard span >= 0 else { return 1 }
    let fit = (span / height).rounded(.down) + 1
    return fit >= Double(count) ? count : Int(fit)
  }

  /// The scale values to draw tags for `prices` at, in the same order, with the most important
  /// tag first. Only the first `room(for:in:halfHeight:)` tags are placed; the rest are `nil`
  /// and not drawn. The placed ones go as by `position(of:in:halfHeight:)`, then, lowest first,
  /// are pushed up until each is a whole tag above the one below it, and from the top back down
  /// where that ran past the area's top; should rounding still leave the lowest below the area,
  /// they are spread evenly from its bottom to its top. Placed values are always distinct.
  public static func positions(of prices: [Double], in area: ClosedRange<Double>, halfHeight: Double) -> [Double?] {
    let kept = room(for: prices.count, in: area, halfHeight: halfHeight)
    let height = halfHeight + halfHeight
    let lowest = area.lowerBound + halfHeight
    let highest = area.upperBound - halfHeight
    let order = prices.indices.prefix(kept).sorted { (prices[$0], $0) < (prices[$1], $1) }
    var shown = order.map { position(of: prices[$0], in: area, halfHeight: halfHeight) }
    var placed = [Double?](repeating: nil, count: prices.count)
    guard let top = shown.indices.last, top > 0 else {
      for (rank, index) in order.enumerated() { placed[index] = shown[rank] }
      return placed
    }
    for index in shown.indices.dropFirst() {
      shown[index] = max(shown[index], shown[index - 1] + height)
    }
    shown[top] = min(shown[top], highest)
    for index in shown.indices.reversed().dropFirst() {
      shown[index] = min(shown[index], shown[index + 1] - height)
    }
    if shown[0] < lowest {
      let step = (highest - lowest) / Double(top)
      shown = shown.indices.map { lowest + Double($0) * step }
    }
    for (rank, index) in order.enumerated() {
      placed[index] = shown[rank]
    }
    return placed
  }
}
