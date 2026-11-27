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
  /// heights still read as far). Candles between the mark and the plate do not count as room
  /// (see `room`); even so the third plate of KXTR's cluster, stacked past the tall candle, needs
  /// 2.14 heights (iPad retest 2026-11-27), so the reach sits between that and 3.
  static let reach: CGFloat = 2.5

  /// Sideways steps in one plate width: a place slides a quarter plate at a time, up to a whole
  /// plate either way (r6: a free place half a plate further right was missed).
  static let slidesPerWidth = 4

  /// The centres of the plates that are drawn, by id; `items` in priority order (first wins).
  /// `offset`: from the mark's centre to the plate's near edge; `gap`: least room between a plate
  /// and anything else, and the plot's edges. When placing in priority order leaves a plate over a
  /// candle or mark, the plates with the fewest clear places go first instead, and that result is
  /// kept if it leaves no more plates out and covers less (a cluster's first plate took the one
  /// clear place of the next: KXTR, iPad retest 2026-11-26).
  static func place(
    _ items: [Item], avoiding obstacles: Obstacles, in frame: CGRect, offset: CGFloat, gap: CGFloat
  ) -> [Int: CGPoint] {
    let inside = frame.insetBy(dx: gap, dy: gap)
    let candles = obstacles.candles.filter { $0.intersects(frame) }
    let glyphs = obstacles.glyphs.filter { $0.intersects(frame) }
    let options: [Options] = items.filter { frame.contains($0.anchor) }.map { item in
      let others = Obstacles(candles: candles, glyphs: glyphs.filter { !$0.contains(item.anchor) })
      let around = others.candles + others.glyphs
      let places = candidates(item, offset: offset, gap: gap, near: others, in: inside)
        .map { (rect: $0, cover: covered($0, by: around, gap: gap)) }
      return Options(id: item.id, places: places)
    }
    let ranked = greedy(options, gap: gap)
    guard ranked.cover > 0 else { return ranked.centres }
    let clear = { (option: Options) in option.places.filter { $0.cover == 0 }.count }
    let constrained = options.enumerated().sorted { (clear($0.element), $0.offset) < (clear($1.element), $1.offset) }
    let tight = greedy(constrained.map { $0.element }, gap: gap)
    let better = tight.centres.count >= ranked.centres.count && tight.cover < ranked.cover
    return better ? tight.centres : ranked.centres
  }

  /// One plate's places, nearest first, each with how much of the candles and marks it covers.
  private struct Options {
    let id: Int
    let places: [(rect: CGRect, cover: CGFloat)]
  }

  /// Each plate in turn takes the nearest of its places that covers least and no plate before it.
  private static func greedy(_ options: [Options], gap: CGFloat) -> (centres: [Int: CGPoint], cover: CGFloat) {
    var taken: [CGRect] = []
    var centres: [Int: CGPoint] = [:]
    var cover: CGFloat = 0
    for option in options {
      // `places` runs nearest first, and `min` keeps the first of equals.
      let free = option.places.filter { covered($0.rect, by: taken, gap: gap) == 0 }
      if let choice = free.min(by: { $0.cover < $1.cover }) {
        taken.append(choice.rect)
        centres[option.id] = CGPoint(x: choice.rect.midX, y: choice.rect.midY)
        cover += choice.cover
      }
    }
    return (centres, cover)
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
  /// up to a whole plate either way, and rows a half plate further above and below. Each row also
  /// has places flush beside each candle or mark near it, a `gap` off its edge: the quarter-plate
  /// steps of a wide plate overshoot the nearest clear place (KXTR). A place over
  /// the mark's own glyph, out of `frame`, or farther than `reach` plates is dropped. Among
  /// equally near places the own side comes first, then the other, then the mark's price.
  private static func candidates(
    _ item: Item, offset: CGFloat, gap: CGFloat, near obstacles: Obstacles, in frame: CGRect
  ) -> [CGRect] {
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
    let span = size.width + reach * size.height
    let beside = (obstacles.candles + obstacles.glyphs).filter {
      $0.maxX >= item.anchor.x - span && $0.minX <= item.anchor.x + span
    }
    for obstacle in beside {
      shifts += [obstacle.maxX + gap - centred, obstacle.minX - gap - size.width - centred]
    }
    let glyph = CGRect(x: item.anchor.x - offset, y: item.anchor.y - offset, width: offset + offset, height: offset + offset)
    let places = tops.flatMap { top in
      shifts.map { CGRect(x: centred + $0, y: top, width: size.width, height: size.height) }
    }
    .filter { frame.contains($0) && !overlaps($0, glyph) }
    let limit = reach * size.height
    let near: [(index: Int, rect: CGRect, room: CGFloat)] = places.enumerated().compactMap { index, rect in
      let room = room(from: item.anchor, to: rect, crossing: obstacles.candles)
      return room <= limit ? (index, rect, room) : nil
    }
    return near.sorted { ($0.room, $0.index) < ($1.room, $1.index) }.map { $0.rect }
  }

  /// Whether two rectangles share some area (touching edges do not).
  private static func overlaps(_ one: CGRect, _ other: CGRect) -> Bool {
    let shared = one.intersection(other)
    return !shared.isNull && shared.width > 0 && shared.height > 0
  }

  /// The room between a point and the nearest point of a rectangle, in points, less the width of
  /// the candles it crosses sideways on the way: a plate just past a tall candle still reads as
  /// its mark's.
  /// KXTR on the iPad retests (2026-11-27): a cluster's only clear places lay past the tall candle
  /// beside it, 2.12 to 2.56 plate heights away counting the candles, and every plate sat on it.
  private static func room(from point: CGPoint, to rect: CGRect, crossing candles: [CGRect]) -> CGFloat {
    let left = min(point.x, rect.maxX)
    let right = max(point.x, rect.minX)
    let top = min(point.y, rect.minY)
    let bottom = max(point.y, rect.maxY)
    let crossed = candles.reduce(0) { sum, candle in
      // Only a candle in between: not the one under the mark, nor one the plate itself covers.
      let under = candle.minX <= point.x && point.x <= candle.maxX
      guard candle.maxY > top, candle.minY < bottom, !under, !overlaps(candle, rect) else { return sum }
      return sum + max(min(candle.maxX, right) - max(candle.minX, left), 0)
    }
    let across = max(max(rect.minX - point.x, 0, point.x - rect.maxX) - crossed, 0)
    let along = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return (across * across + along * along).squareRoot()
  }
}
