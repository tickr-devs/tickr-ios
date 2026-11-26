#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Where the price pane's plates ("EXIT +$93.38", "BUY 50 @ 15.74", a decision's "WATCH") sit
/// on screen. Each plate in turn, in priority order, looks at places near its mark: right above
/// and below it, slid sideways, beside it at its price, then a half plate further each step up
/// to `reach` plates away. It takes the nearest place that covers no candle or mark, else the
/// one that covers least;
/// it never covers another plate, and with no such place within reach it is left out (its mark
/// stays, and pointing at the candle still shows it). Plates stay inside the visible plot, a gap
/// from its edges. Duo retests, 2026-11-26: a decision's label sat under an exit's plate, a fill's
/// plate under the stop-out's, plates covered the candles (the owner's old complaint about
/// BUY/EXIT plates), and plates sent to the far edge no longer read as their mark's.
enum MarkPlateLayout {
  /// Which side of its mark a plate looks at first.
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

  /// What a plate should not cover where it can help it, on screen: the candles, and the marks'
  /// glyphs (its own mark's glyph, the one over its anchor, is not in its way).
  struct Obstacles {
    var candles: [CGRect] = []
    var glyphs: [CGRect] = []
  }

  /// Farthest a plate moves above or below its mark, in its own heights: farther, it no longer
  /// reads as the mark's (r4: "BUY" 230 px above its arrow; r5: three heights still read as far).
  static let reach: CGFloat = 2

  /// The centres of the plates that are drawn, by id; `items` in priority order (first wins).
  /// `offset`: from the mark's centre to the plate's near edge; `gap`: least room between a plate
  /// and anything else, and the plot's edges.
  static func place(
    _ items: [Item], avoiding obstacles: Obstacles, in frame: CGRect, offset: CGFloat, gap: CGFloat
  ) -> [Int: CGPoint] {
    let inside = frame.insetBy(dx: gap, dy: gap)
    let candles = obstacles.candles.filter { $0.intersects(frame) }
    let glyphs = obstacles.glyphs.filter { $0.intersects(frame) }
    var taken: [CGRect] = []
    var centres: [Int: CGPoint] = [:]
    for item in items where frame.contains(item.anchor) {
      let around = candles + glyphs.filter { !$0.contains(item.anchor) }
      let places = candidates(item, offset: offset, in: inside).filter { covered($0, by: taken, gap: gap) == 0 }
      // The nearest place that covers least: `places` runs nearest first, and `min` keeps the
      // first of equals.
      let choice = places.map { (rect: $0, cover: covered($0, by: around, gap: gap)) }.min { $0.cover < $1.cover }
      if let choice {
        taken.append(choice.rect)
        centres[item.id] = CGPoint(x: choice.rect.midX, y: choice.rect.midY)
      }
    }
    return centres
  }

  /// How much of `rect` lies within `gap` of `others`, in square points (0: clear of them all).
  private static func covered(_ rect: CGRect, by others: [CGRect], gap: CGFloat) -> CGFloat {
    others.reduce(0) { sum, other in
      let shared = other.insetBy(dx: -gap, dy: -gap).intersection(rect)
      return shared.isNull ? sum : sum + shared.width * shared.height
    }
  }

  /// The places near a mark, nearest first: on its own side then the other, right by it; its own
  /// side slid half a plate right and left; beside it at its price (right, then left); then a
  /// half plate further above and below at each step, up to `reach`. A place that would leave
  /// `frame` across the price is dropped; along the time axis a plate slides inside.
  private static func candidates(_ item: Item, offset: CGFloat, in frame: CGRect) -> [CGRect] {
    let size = item.size
    let step = size.height / 2
    let steps = Int((reach * size.height / step).rounded())
    let above = { (distance: CGFloat) in item.anchor.y - offset - distance - size.height }
    let below = { (distance: CGFloat) in item.anchor.y + offset + distance }
    let sides = { (distance: CGFloat) in
      item.side == .above ? [above(distance), below(distance)] : [below(distance), above(distance)]
    }
    let centred = item.anchor.x - size.width / 2
    let slide = { (left: CGFloat) in min(max(left, frame.minX), frame.maxX - size.width) }
    let plate = { (left: CGFloat, top: CGFloat) in CGRect(x: slide(left), y: top, width: size.width, height: size.height) }
    let near = sides(0)
    var places = near.map { plate(centred, $0) }
    places += [centred + size.width / 2, centred - size.width / 2].map { plate($0, near[0]) }
    let level = item.anchor.y - size.height / 2
    places += [item.anchor.x + offset, item.anchor.x - offset - size.width].map {
      CGRect(x: $0, y: level, width: size.width, height: size.height)
    }
    for index in 1...steps {
      places += sides(CGFloat(index) * step).map { plate(centred, $0) }
    }
    return places.filter { frame.contains($0) }
  }
}
