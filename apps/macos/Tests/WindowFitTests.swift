import CoreGraphics
import Testing
import TickrDesign
@testable import TickrScreens

/// The main window fits the screen (owner decision 2026-11-16, option A): its least size is capped
/// to the room the screen leaves it, and the Overview stacks its cards there with the Safety · bot
/// card reachable without a sideways scroll.
@MainActor
@Suite("Window fits the screen")
struct WindowFitTests {
  /// The comfortable least content size of the English fixtures (1377 points wide since #531)
  /// and the room a large display leaves.
  private static let comfortable = CGSize(width: 1377, height: 762)
  private static let large = CGSize(width: 1728, height: 1040)
  /// The title bar and toolbar of the compact unified style, in points.
  private static let chrome: CGFloat = 40

  @Test("A screen larger than the comfortable size keeps it")
  func largeScreenKeepsComfortable() {
    #expect(WindowFit.least(comfortable: Self.comfortable, room: Self.large) == Self.comfortable)
  }

  @Test("No screen yet keeps the comfortable size")
  func noScreenKeepsComfortable() {
    #expect(WindowFit.least(comfortable: Self.comfortable, room: nil) == Self.comfortable)
  }

  @Test("A 1280 × 800 display caps the width and the height to its room")
  func laptopCapsBoth() {
    let room = WindowFit.room(visible: CGSize(width: 1280, height: 775), chrome: Self.chrome)
    #expect(room == CGSize(width: 1280, height: 735))
    #expect(WindowFit.least(comfortable: Self.comfortable, room: room) == CGSize(width: 1280, height: 735))
  }

  @Test("A 1024 × 768 display caps the width and the height to its room")
  func smallDisplayCapsBoth() {
    let room = WindowFit.room(visible: CGSize(width: 1024, height: 768), chrome: Self.chrome)
    #expect(WindowFit.least(comfortable: Self.comfortable, room: room) == CGSize(width: 1024, height: 728))
  }

  @Test("Only the side that does not fit is capped")
  func capsOneSide() {
    let tall = CGSize(width: 1280, height: 1400)
    #expect(WindowFit.least(comfortable: Self.comfortable, room: tall) == CGSize(width: 1280, height: 762))
    let wide = CGSize(width: 2560, height: 700)
    #expect(WindowFit.least(comfortable: Self.comfortable, room: wide) == CGSize(width: 1377, height: 700))
  }

  @Test("A room is never negative")
  func roomNeverNegative() {
    #expect(WindowFit.room(visible: CGSize(width: 10, height: 20), chrome: Self.chrome) == CGSize(width: 10, height: 0))
  }

  @Test("A window larger than the screen is shrunk and moved inside it")
  func fitsWindowIntoScreen() {
    let visible = CGRect(x: 0, y: 25, width: 1280, height: 750)
    let window = CGRect(x: 100, y: 0, width: 1377, height: 810)
    #expect(WindowFit.fitted(window, in: visible) == CGRect(x: 0, y: 25, width: 1280, height: 750))
  }

  @Test("A window off the screen's edge is moved back, its size kept")
  func movesWindowBack() {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let window = CGRect(x: 400, y: 200, width: 1200, height: 800)
    #expect(WindowFit.fitted(window, in: visible) == CGRect(x: 240, y: 75, width: 1200, height: 800))
  }

  @Test("A window inside the screen stays as it is")
  func keepsWindowInside() {
    let visible = CGRect(x: 0, y: 0, width: 1728, height: 1080)
    let window = CGRect(x: 50, y: 60, width: 1440, height: 920)
    #expect(WindowFit.fitted(window, in: visible) == window)
  }

  @Test("A screen on a second display keeps its origin")
  func secondDisplay() {
    let visible = CGRect(x: 1728, y: 0, width: 1024, height: 743)
    let window = CGRect(x: 1700, y: 0, width: 1377, height: 810)
    #expect(WindowFit.fitted(window, in: visible) == visible)
  }

  @Test("Overview needs one column of cards, so it never scrolls sideways at a capped window")
  func overviewLeastIsOneColumn() {
    // A 1024-point window beside the widest sidebar leaves the Overview far more than one column.
    #expect(OverviewView.leastSize.width < 1024 - RootView.sidebarMax)
    #expect(OverviewView.leastSize.height == 0)
  }

  @Test("Overview stacks to two columns, then one column with the Safety card first, never wider than the room")
  func overviewStacks() {
    let grid = CardGrid(arrangements: OverviewView.arrangements, spacing: 16, minHeight: 0)
    let three = OverviewView.threeColumnsMinWidth - OverviewView.padding * CardArrangement.paddedEdges
    #expect(grid.arrangement(for: three)?.rows.contains { $0.columns.count == 3 } == true)
    let twoWidth = OverviewView.twoColumnsMinGridWidth
    #expect(grid.arrangement(for: twoWidth)?.rows.contains { $0.columns.count == 2 } == true)
    let one = grid.arrangement(for: twoWidth - 1)
    #expect(one?.rows.allSatisfy { $0.columns.count == 1 } == true)
    // Header, result, then the Safety · bot card (slot 5).
    #expect(one?.rows.prefix(3).map { $0.columns[0].cards } == [[0], [1], [5]])
    // Every card of the screen is placed in each arrangement.
    for arrangement in OverviewView.arrangements {
      let cards = arrangement.rows.flatMap { $0.columns.flatMap(\.cards) }.sorted()
      #expect(cards == Array(0..<9))
    }
  }

  @Test("Overview's board follows the grid width; the result is one line where it cannot sit beside the header")
  func overviewLayouts() {
    let three = OverviewView.threeColumnsMinWidth - OverviewView.padding * CardArrangement.paddedEdges
    #expect(OverviewView.layout(gridWidth: three) == .board)
    #expect(OverviewView.layout(gridWidth: three - 1) == .twoColumns)
    let beside = OverviewView.headerBesideNarrowResultMinGridWidth
    #expect(beside > OverviewView.twoColumnsMinGridWidth && beside < three)
    #expect(OverviewView.layout(gridWidth: beside - 1) == .twoColumnsResultBelow)
    #expect(OverviewView.layout(gridWidth: OverviewView.twoColumnsMinGridWidth - 1) == .oneColumn)
    #expect(OverviewLayout.oneColumn.resultInline && OverviewLayout.twoColumnsResultBelow.resultInline)
    #expect(!OverviewLayout.twoColumns.resultInline && !OverviewLayout.board.sized)
    // The arrangement each layout names is the one the grid picks at that width.
    let grid = CardGrid(arrangements: OverviewView.arrangements, spacing: 16, minHeight: 0)
    #expect(grid.arrangement(for: beside)?.rows.first?.columns.count == 2)
    #expect(grid.arrangement(for: beside - 1)?.rows.first?.columns.count == 1)
  }

  @Test("Stages share rows evenly when one row would break a word: 9 as 5 and 4")
  func stageRows() {
    #expect(StageRows.perRow(count: 9, width: 900, leastCellWidth: 80) == 9)
    #expect(StageRows.perRow(count: 9, width: 719, leastCellWidth: 80) == 5)
    #expect(StageRows.perRow(count: 9, width: 400, leastCellWidth: 80) == 5)
    #expect(StageRows.perRow(count: 9, width: 399, leastCellWidth: 80) == 3)
    #expect(StageRows.perRow(count: 9, width: 10, leastCellWidth: 80) == 1)
    #expect(StageRows.perRow(count: 0, width: 900, leastCellWidth: 80) == 0)
  }

  @Test("A stage cell holds its longest word, never less than its ring")
  func stageCellWidth() {
    let short = StageRows.leastCellWidth(names: ["A"], values: [])
    #expect(short == Tokens.Size.stage + Tokens.Space.xs * CardArrangement.paddedEdges)
    let long = StageRows.leastCellWidth(names: ["broker stop", "reconcile"], values: ["141 cotizados"])
    #expect(long > short)
    #expect(StageRows.leastCellWidth(names: ["reconcile reconcile"], values: [])
      == StageRows.leastCellWidth(names: ["reconcile"], values: []))
  }

  @Test("The title bar gives up the day controls first, then the code version, then the status text")
  func titleBarTiers() {
    let tiers = TitleBarFit.tiers
    #expect(tiers.first == .whole)
    #expect(tiers.map(\.stepper) == [true, false, false, false])
    #expect(tiers.map(\.code) == [true, true, false, false])
    #expect(tiers.map(\.statusText) == [true, true, true, false])
  }

  @Test("The sidebar is an icon rail only where the full sidebar leaves Overview less than two columns")
  func railThreshold() {
    #expect(WindowWidthFit.railBelowWidth == RootView.sidebarIdeal + OverviewView.twoColumnsMinScreenWidth)
    #expect(WindowWidthFit.railBelowWidth < 1024 && WindowWidthFit.railBelowWidth > 640)
    #expect(WindowWidthFit.leastMeasured > 1)
  }
}
