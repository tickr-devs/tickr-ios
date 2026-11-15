import Foundation

/// Where price tags (the last price, entries, stops) sit on the price pane's scale: each at its
/// price when the whole tag fits in the price area on screen, else pinned to the nearer edge of
/// that area, so a tag never hangs below the plot or over the volume bars; tags that would
/// touch are then pushed apart, still inside the area. A tag always reads its own price.
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

  /// The scale values to draw tags for `prices` at, in the same order: each placed as by
  /// `position(of:in:halfHeight:)`, then, lowest first, pushed up until it is a whole tag above
  /// the one below it, and from the top back down where that ran past the area's top. When the
  /// tags cannot all fit apart, they are spread evenly from the bottom to the top of the area.
  public static func positions(of prices: [Double], in area: ClosedRange<Double>, halfHeight: Double) -> [Double] {
    let height = halfHeight + halfHeight
    let lowest = area.lowerBound + halfHeight
    let highest = area.upperBound - halfHeight
    let order = prices.indices.sorted { (prices[$0], $0) < (prices[$1], $1) }
    var shown = order.map { position(of: prices[$0], in: area, halfHeight: halfHeight) }
    guard let top = shown.indices.last, top > 0 else { return shown }
    for index in shown.indices.dropFirst() {
      shown[index] = max(shown[index], shown[index - 1] + height)
    }
    shown[top] = min(shown[top], highest)
    for index in shown.indices.reversed().dropFirst() {
      shown[index] = min(shown[index], shown[index + 1] - height)
    }
    if shown[0] < lowest {
      let step = max(highest - lowest, 0) / Double(top)
      shown = shown.indices.map { lowest + Double($0) * step }
    }
    var placed = prices
    for (rank, index) in order.enumerated() {
      placed[index] = shown[rank]
    }
    return placed
  }
}
