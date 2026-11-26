import Foundation

/// Where the price pane's plates ("EXIT +$93.38", "BUY 50 @ 15.74", a decision's "WATCH") sit
/// on screen, so none covers another: each in turn, in priority order, takes its own side of its
/// mark, else the other side, else it is left out (its mark stays, and pointing at the candle
/// still shows it). Plates stay inside the visible plot. Duo retest, 2026-11-26: a decision's
/// label sat under an exit's plate, and a fill's plate under the stop-out's a few candles on.
enum MarkPlateLayout {
  /// Which side of its mark a plate takes first.
  enum Side {
    case above, below
  }

  struct Item {
    let id: Int
    /// The mark's centre on screen.
    let anchor: CGPoint
    let size: CGSize
    let side: Side
  }

  /// The centres of the plates that are drawn, by id; `items` in priority order (first wins).
  /// `offset`: from the mark's centre to the plate's near edge; `gap`: least room between plates.
  static func place(_ items: [Item], in frame: CGRect, offset: CGFloat, gap: CGFloat) -> [Int: CGPoint] {
    var taken: [CGRect] = []
    var centres: [Int: CGPoint] = [:]
    for item in items where frame.contains(item.anchor) {
      let sides = item.side == .above ? [Side.above, .below] : [.below, .above]
      let fits = sides.lazy
        .map { rect(item, side: $0, offset: offset, in: frame) }
        .first { candidate in !taken.contains { $0.insetBy(dx: -gap, dy: -gap).intersects(candidate) } }
      if let fits {
        taken.append(fits)
        centres[item.id] = CGPoint(x: fits.midX, y: fits.midY)
      }
    }
    return centres
  }

  /// The plate's rectangle on one side of its mark, moved inside `frame` where it would cross it.
  private static func rect(_ item: Item, side: Side, offset: CGFloat, in frame: CGRect) -> CGRect {
    let width = item.size.width
    let height = item.size.height
    let top = side == .above ? item.anchor.y - offset - height : item.anchor.y + offset
    let left = item.anchor.x - width / 2
    return CGRect(
      x: min(max(left, frame.minX), frame.maxX - width),
      y: min(max(top, frame.minY), frame.maxY - height),
      width: width, height: height)
  }
}
