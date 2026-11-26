#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Where the price pane's plates ("EXIT +$93.38", "BUY 50 @ 15.74", a decision's "WATCH") sit
/// on screen, so none covers another and, where there is room, none covers a candle or a mark.
/// Each plate in turn, in priority order, tries its own side of its mark, the other side, then
/// clear space above and below the candles under it; the first place that touches nothing wins,
/// else the first that touches no plate, else it is left out (its mark stays, and pointing at the
/// candle still shows it). Plates stay inside the visible plot. Duo retest, 2026-11-26: a
/// decision's label sat under an exit's plate, a fill's plate under the stop-out's a few candles
/// on, and plates covered the candles (the owner's old complaint about BUY/EXIT plates).
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
  /// What a plate should not cover where it can help it, on screen: the candles, and the marks'
  /// glyphs (a mark's own, centred on its anchor, is not in its way).
  struct Obstacles {
    var candles: [CGRect] = []
    var glyphs: [CGRect] = []
  }

  /// `offset`: from the mark's centre to the plate's near edge; `gap`: least room between a plate
  /// and anything else.
  static func place(
    _ items: [Item], avoiding obstacles: Obstacles, in frame: CGRect, offset: CGFloat, gap: CGFloat
  ) -> [Int: CGPoint] {
    let shownCandles = obstacles.candles.filter { $0.intersects(frame) }
    let shownGlyphs = obstacles.glyphs.filter { $0.intersects(frame) }
    var taken: [CGRect] = []
    var centres: [Int: CGPoint] = [:]
    for item in items where frame.contains(item.anchor) {
      let around = shownCandles + shownGlyphs.filter { CGPoint(x: $0.midX, y: $0.midY) != item.anchor }
      let places = candidates(item, obstacles: around, offset: offset, gap: gap, in: frame)
      let choice = places.first { clear($0, of: taken + around, gap: gap) } ?? places.first { clear($0, of: taken, gap: gap) }
      if let choice {
        taken.append(choice)
        centres[item.id] = CGPoint(x: choice.midX, y: choice.midY)
      }
    }
    return centres
  }

  /// Whether `rect` keeps `gap` from every one of `others` (touching at that distance is clear).
  private static func clear(_ rect: CGRect, of others: [CGRect], gap: CGFloat) -> Bool {
    !others.contains { other in
      let shared = other.insetBy(dx: -gap, dy: -gap).intersection(rect)
      return !shared.isNull && shared.width > 0 && shared.height > 0
    }
  }

  /// The places a plate may take, in order: its own side of its mark, the other side, just above
  /// everything under it, just below everything under it.
  private static func candidates(
    _ item: Item, obstacles: [CGRect], offset: CGFloat, gap: CGFloat, in frame: CGRect
  ) -> [CGRect] {
    let own = item.side == .above ? item.anchor.y - offset - item.size.height : item.anchor.y + offset
    let other = item.side == .above ? item.anchor.y + offset : item.anchor.y - offset - item.size.height
    var tops = [own, other]
    let left = min(max(item.anchor.x - item.size.width / 2, frame.minX), frame.maxX - item.size.width)
    let under = obstacles.filter { $0.maxX > left && $0.minX < left + item.size.width }
    if let highest = under.map(\.minY).min(), let lowest = under.map(\.maxY).max() {
      tops += [highest - gap - item.size.height, lowest + gap]
    }
    return tops.map { top in
      CGRect(
        x: left, y: min(max(top, frame.minY), frame.maxY - item.size.height),
        width: item.size.width, height: item.size.height)
    }
  }
}
