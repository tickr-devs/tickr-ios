import SwiftUI
import Testing
@testable import TickrScreens

@Suite("Card grid")
struct CardGridTests {
  /// Every card 100 points tall at any width.
  private static func fixedHeight(_: Int, _: ProposedViewSize) -> CGFloat { 100 }

  private let grid = CardGrid(
    arrangements: [
      CardArrangement(minWidth: 600, rows: [
        CardRow(columns: [
          CardColumn(width: .fixed(200), cards: [0, 1]),
          CardColumn(width: .share(1), cards: [2]),
        ], height: .fillsRest(atLeast: 0))
      ]),
      CardArrangement(minWidth: 0, rows: [
        CardRow(columns: [CardColumn(width: .share(1), cards: [2, 0, 1])], linesUp: false)
      ]),
    ],
    spacing: 10, minHeight: 500)

  @Test("The widest arrangement the width allows is used, the last one below every threshold")
  func picksByWidth() {
    #expect(grid.arrangement(for: 800)?.minWidth == 600)
    #expect(grid.arrangement(for: 600)?.minWidth == 600)
    #expect(grid.arrangement(for: 599)?.minWidth == 0)
  }

  @Test("Columns share what fixed columns and gaps leave; the last card fills the rest of the height")
  func wideLayout() {
    let plan = grid.plan(width: 810, count: 3, height: Self.fixedHeight)
    #expect(plan.frames[0] == CGRect(x: 0, y: 0, width: 200, height: 100))
    #expect(plan.frames[1] == CGRect(x: 0, y: 110, width: 200, height: 390))
    #expect(plan.frames[2] == CGRect(x: 210, y: 0, width: 600, height: 500))
    #expect(plan.size == CGSize(width: 810, height: 500))
  }

  @Test("A narrow width stacks the same cards in the narrow arrangement's order, each at its own height")
  func narrowLayout() {
    let plan = grid.plan(width: 400, count: 3, height: Self.fixedHeight)
    #expect(plan.frames[2] == CGRect(x: 0, y: 0, width: 400, height: 100))
    #expect(plan.frames[0] == CGRect(x: 0, y: 110, width: 400, height: 100))
    #expect(plan.frames[1] == CGRect(x: 0, y: 220, width: 400, height: 100))
    #expect(plan.size == CGSize(width: 400, height: 320))
  }
}
