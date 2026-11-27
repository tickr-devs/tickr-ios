#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import Testing
@testable import TickrScreens

@Suite("Chart plates placed apart")
struct MarkPlateLayoutTests {
  /// A plot of 400 by 300 points, plates of 80 by 16, 4 points from the mark, 2 between plates.
  let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
  let size = CGSize(width: 80, height: 16)
  let offset: CGFloat = 4
  let gap: CGFloat = 2

  private func place(
    _ items: [MarkPlateLayout.Item], candles: [CGRect] = [], glyphs: [CGRect] = []
  ) -> [Int: CGPoint] {
    MarkPlateLayout.place(items, avoiding: .init(candles: candles, glyphs: glyphs), in: frame, offset: offset, gap: gap)
  }

  @Test("A plate sits on its own side of its mark")
  func ownSide() throws {
    let centres = place([
      .init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 300, y: 150), size: size, side: .below),
    ])
    #expect(try #require(centres[0]) == CGPoint(x: 100, y: 150 - offset - size.height / 2))
    #expect(try #require(centres[1]) == CGPoint(x: 300, y: 150 + offset + size.height / 2))
  }

  @Test("A later plate that would cover an earlier one takes the other side")
  func otherSide() throws {
    // An exit, then a decision one candle on at the same price: both want the space above.
    let centres = place([
      .init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 110, y: 150), size: size, side: .above),
    ])
    #expect(try #require(centres[1]).y > 150)
  }

  @Test("A plate with no free side is left out; plates far apart all stay")
  func leftOut() {
    // A plot just two plates high and too narrow for a plate beside the marks within reach: the
    // third plate on the same spot finds no free place.
    let low = CGRect(x: 0, y: 0, width: 200, height: 48)
    let crowded = MarkPlateLayout.place([
      .init(id: 0, anchor: CGPoint(x: 100, y: 24), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 100, y: 24), size: size, side: .below),
      .init(id: 2, anchor: CGPoint(x: 105, y: 24), size: size, side: .above),
    ], avoiding: .init(), in: low, offset: offset, gap: gap)
    #expect(Set(crowded.keys) == [0, 1])
    // An entry's plate below its mark and a decision's above it, 60 points apart in price:
    // nothing meets, so the decision keeps its label (the retest's lost "ENTER").
    let apart = place([
      .init(id: 0, anchor: CGPoint(x: 100, y: 100), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 120, y: 160), size: size, side: .above),
    ])
    #expect(Set(apart.keys) == [0, 1])
  }

  @Test("A fill's plate under its mark gives way to a stop-out's above a lower mark")
  func fillUnderStopOut() throws {
    // The exit is placed first, above its mark 20 points lower than the fill: the fill's plate
    // below its own mark would cover it, so it goes above.
    let centres = place([
      .init(id: 0, anchor: CGPoint(x: 140, y: 170), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 100, y: 150), size: size, side: .below),
    ])
    #expect(try #require(centres[1]).y < 150)
  }

  @Test("Plates stay inside the plot, and a mark off screen has none")
  func insidePlot() throws {
    let centres = place([
      .init(id: 0, anchor: CGPoint(x: 10, y: 5), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 500, y: 150), size: size, side: .above),
    ])
    let edge = try #require(centres[0])
    #expect(edge.x - size.width / 2 >= frame.minX)
    #expect(edge.y - size.height / 2 >= frame.minY)
    #expect(centres[1] == nil)
  }

  /// The plate drawn at `centre`, and whether it keeps `gap` from `rect`.
  private func plate(at centre: CGPoint) -> CGRect {
    CGRect(x: centre.x - size.width / 2, y: centre.y - size.height / 2, width: size.width, height: size.height)
  }

  private func clear(_ centre: CGPoint, of rect: CGRect) -> Bool {
    let shared = rect.insetBy(dx: -gap, dy: -gap).intersection(plate(at: centre))
    return shared.isNull || shared.width * shared.height == 0
  }

  /// The room between a mark and its plate's nearest point, in plate heights.
  private func reach(_ centre: CGPoint, from mark: CGPoint) -> CGFloat {
    let rect = plate(at: centre)
    let across = max(rect.minX - mark.x, 0, mark.x - rect.maxX)
    let along = max(rect.minY - mark.y, 0, mark.y - rect.maxY)
    return (across * across + along * along).squareRoot() / size.height
  }

  @Test("A plate moves off the candle under its mark to the nearest clear place, within reach")
  func offCandles() throws {
    let mark = CGPoint(x: 100, y: 150)
    for candle in [CGRect(x: 95, y: 120, width: 10, height: 80), CGRect(x: 95, y: 0, width: 10, height: 170)] {
      let centre = try #require(place([.init(id: 0, anchor: mark, size: size, side: .above)], candles: [candle])[0])
      #expect(clear(centre, of: candle))
      #expect(reach(centre, from: mark) <= MarkPlateLayout.reach)
    }
    // Candles filling the whole plot: the plate keeps its own side, over them.
    let full = CGRect(x: 0, y: 0, width: 400, height: 300)
    let over = place([.init(id: 0, anchor: mark, size: size, side: .above)], candles: [full])
    #expect(try #require(over[0]) == CGPoint(x: 100, y: 150 - offset - size.height / 2))
  }

  @Test("A mark's own glyph is not in its plate's way; another mark's is")
  func glyphs() throws {
    let mark = CGPoint(x: 100, y: 150)
    let own = CGRect(x: 92, y: 142, width: 16, height: 16)
    let alone = place([.init(id: 0, anchor: mark, size: size, side: .above)], glyphs: [own])
    #expect(try #require(alone[0]) == CGPoint(x: 100, y: 150 - offset - size.height / 2))
    let neighbour = CGRect(x: 112, y: 122, width: 16, height: 16)
    let moved = try #require(place([.init(id: 0, anchor: mark, size: size, side: .above)], glyphs: [own, neighbour])[0])
    #expect(clear(moved, of: neighbour))
    #expect(reach(moved, from: mark) <= MarkPlateLayout.reach)
  }

  @Test("Where candles fill the height, a plate goes beside its mark at its price, never far off")
  func besideMark() throws {
    // A tall candle from 20 to 280 under a fill's mark: no place above or below within reach
    // is clear, beside the mark covers least.
    let candle = CGRect(x: 95, y: 20, width: 10, height: 260)
    let centres = place([.init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .below)], candles: [candle])
    let centre = try #require(centres[0])
    #expect(centre.y == 150)
    #expect(centre.x - size.width / 2 >= 100 + offset)
  }

  @Test("A plate slides sideways off a candle beside its mark before moving further away")
  func slides() throws {
    // Candles to the left of the exit's mark, above and below it, cover both centred places.
    let candle = CGRect(x: 60, y: 100, width: 38, height: 60)
    let lower = CGRect(x: 60, y: 175, width: 38, height: 60)
    let centres = place(
      [.init(id: 0, anchor: CGPoint(x: 100, y: 170), size: size, side: .above)], candles: [candle, lower])
    let centre = try #require(centres[0])
    #expect(centre.y < 170)
    #expect(centre.x - size.width / 2 >= candle.maxX + gap)
  }

  @Test("In a cluster, a plate with few clear places is not crowded onto a candle by an earlier one")
  func cluster() throws {
    // A fill's plate below its mark and the next mark's above, 10 points apart, between two
    // candles: in priority order the first takes the second's one clear place (KXTR).
    let candles = [CGRect(x: 220, y: 150, width: 10, height: 40), CGRect(x: 290, y: 130, width: 10, height: 70)]
    let centres = place([
      .init(id: 0, anchor: CGPoint(x: 270, y: 150), size: size, side: .below),
      .init(id: 1, anchor: CGPoint(x: 270, y: 160), size: size, side: .above),
    ], candles: candles)
    #expect(Set(centres.keys) == [0, 1])
    for centre in centres.values {
      #expect(candles.allSatisfy { clear(centre, of: $0) })
    }
  }

  @Test("A cluster on a tall candle stacks its plates clear of it, as measured on the iPad")
  func tallCandleCluster() throws {
    // KXTR on the iPad in landscape, 2026-11-27, measured from the screenshot in points: a fill,
    // an entry decision and a watch at one price on a short candle, two candles before a tall one.
    // Every clear place lay 2.12 to 2.38 plate heights away, and the fill's quarter-plate steps
    // overshot the nearest clear place beside the tall candle.
    let line: CGFloat = 13.5
    let plot = CGRect(x: 261, y: 406.75, width: 609, height: 232.25)
    let candles = [
      CGRect(x: 278, y: 425.5, width: 4.5, height: 56), CGRect(x: 293.5, y: 421, width: 4.5, height: 8),
      CGRect(x: 301.5, y: 421, width: 4.5, height: 8), CGRect(x: 309, y: 421.25, width: 4.5, height: 198.75),
      CGRect(x: 317, y: 613, width: 4.5, height: 8),
    ]
    let marks = [CGPoint(x: 276.4, y: 479.4), CGPoint(x: 274.5, y: 479.5), CGPoint(x: 272.75, y: 479.5)]
    let glyphs = marks.map { CGRect(x: $0.x - line / 2, y: $0.y - line / 2, width: line, height: line) }
    let sizes = [CGSize(width: 101, height: 17.5), CGSize(width: 40.5, height: 17.5), CGSize(width: 40.5, height: 17.5)]
    let items = (0..<marks.count).map { index in
      MarkPlateLayout.Item(id: index, anchor: marks[index], size: sizes[index], side: index == 0 ? .below : .above)
    }
    let centres = MarkPlateLayout.place(
      items, avoiding: .init(candles: candles, glyphs: glyphs), in: plot, offset: line / 2 + gap, gap: gap)
    #expect(Set(centres.keys) == [0, 1, 2])
    for item in items {
      let centre = try #require(centres[item.id])
      let rect = CGRect(
        x: centre.x - item.size.width / 2, y: centre.y - item.size.height / 2,
        width: item.size.width, height: item.size.height)
      #expect(candles.allSatisfy { candle in
        let shared = candle.insetBy(dx: -gap, dy: -gap).intersection(rect)
        return shared.isNull || shared.width * shared.height == 0
      })
    }
  }
}
