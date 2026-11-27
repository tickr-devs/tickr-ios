#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Where the price pane's plates ("EXIT +$93.38", "BUY 50 @ 15.74", a decision's "WATCH") sit
/// on screen. Each plate in turn, in priority order, looks at places around its mark, nearest
/// first, up to `reach` plates away: above, below and beside it, slid sideways a quarter plate at
/// a time. It takes the nearest place that covers no candle or mark, else the one that covers
/// least;
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

  /// Farthest a plate's nearest edge is from its mark's centre, in the plate's own heights:
  /// farther, it no longer reads as the mark's (r4: "BUY" 230 px above its arrow; r5: three
  /// heights still read as far).
  static let reach: CGFloat = 2

  /// Sideways steps in one plate width: a place slides a quarter plate at a time, up to a whole
  /// plate either way (r6: a free place half a plate further right was missed).
  static let slidesPerWidth = 4

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

  /// The places near a mark, nearest first (by the room between the mark's centre and the plate):
  /// rows on its own side, the other side and at its price, each slid a quarter plate at a time
  /// up to a whole plate either way, and rows a half plate further above and below. A place over
  /// the mark's own glyph, out of `frame`, or farther than `reach` plates is dropped. Among
  /// equally near places the own side comes first, then the other, then the mark's price.
  private static func candidates(_ item: Item, offset: CGFloat, in frame: CGRect) -> [CGRect] {
    let size = item.size
    let step = size.height / 2
    let steps = Int((reach * size.height / step).rounded())
    let above = { (distance: CGFloat) in item.anchor.y - offset - distance - size.height }
    let below = { (distance: CGFloat) in item.anchor.y + offset + distance }
    var tops: [CGFloat] = []
    for index in 0...steps {
      let distance = CGFloat(index) * step
      tops += item.side == .above ? [above(distance), below(distance)] : [below(distance), above(distance)]
      if index == 0 { tops.append(item.anchor.y - size.height / 2) }
    }
    let slide = size.width / CGFloat(slidesPerWidth)
    var shifts: [CGFloat] = [0]
    for index in 1...slidesPerWidth {
      let shift = CGFloat(index) * slide
      shifts += [shift, -shift]
    }
    let centred = item.anchor.x - size.width / 2
    let glyph = CGRect(x: item.anchor.x - offset, y: item.anchor.y - offset, width: offset + offset, height: offset + offset)
    let places = tops.flatMap { top in
      shifts.map { CGRect(x: centred + $0, y: top, width: size.width, height: size.height) }
    }
    .filter { frame.contains($0) && !overlaps($0, glyph) }
    let limit = reach * size.height
    let near: [(index: Int, rect: CGRect, room: CGFloat)] = places.enumerated().compactMap { index, rect in
      let room = room(from: item.anchor, to: rect)
      return room <= limit ? (index, rect, room) : nil
    }
    return near.sorted { ($0.room, $0.index) < ($1.room, $1.index) }.map { $0.rect }
  }

  /// Whether two rectangles share some area (touching edges do not).
  private static func overlaps(_ one: CGRect, _ other: CGRect) -> Bool {
    let shared = one.intersection(other)
    return !shared.isNull && shared.width > 0 && shared.height > 0
  }

  /// The room between a point and the nearest point of a rectangle, in points.
  private static func room(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let across = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let along = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return (across * across + along * along).squareRoot()
  }
}
