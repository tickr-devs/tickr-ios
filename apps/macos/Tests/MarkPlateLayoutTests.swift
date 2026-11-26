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
    let crowded = place([
      .init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above),
      .init(id: 1, anchor: CGPoint(x: 100, y: 150), size: size, side: .below),
      .init(id: 2, anchor: CGPoint(x: 105, y: 150), size: size, side: .above),
    ])
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

  @Test("A plate moves off the candles under it, above or below them, when there is room")
  func offCandles() throws {
    // A tall candle from 100 to 200 under an exit's mark at 150: above its high instead.
    let candle = CGRect(x: 95, y: 100, width: 10, height: 100)
    let above = place([.init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above)], candles: [candle])
    #expect(try #require(above[0]).y + size.height / 2 <= candle.minY - gap)
    // A candle reaching the plot's top: the plate goes below its low.
    let top = CGRect(x: 95, y: 0, width: 10, height: 200)
    let below = place([.init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above)], candles: [top])
    #expect(try #require(below[0]).y - size.height / 2 >= top.maxY + gap)
    // Candles filling the whole plot: the plate keeps its own side, over them.
    let full = CGRect(x: 0, y: 0, width: 400, height: 300)
    let over = place([.init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above)], candles: [full])
    #expect(try #require(over[0]) == CGPoint(x: 100, y: 150 - offset - size.height / 2))
  }

  @Test("A mark's own glyph is not in its plate's way; another mark's is")
  func glyphs() throws {
    let own = CGRect(x: 92, y: 142, width: 16, height: 16)
    let alone = place([.init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above)], glyphs: [own])
    #expect(try #require(alone[0]) == CGPoint(x: 100, y: 150 - offset - size.height / 2))
    let neighbour = CGRect(x: 112, y: 122, width: 16, height: 16)
    let moved = place([.init(id: 0, anchor: CGPoint(x: 100, y: 150), size: size, side: .above)], glyphs: [own, neighbour])
    #expect(try #require(moved[0]).y > 150)
  }
}
