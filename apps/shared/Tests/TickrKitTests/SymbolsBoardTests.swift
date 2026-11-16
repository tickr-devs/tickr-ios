import Foundation
import Testing

@testable import TickrKit

@Suite("Symbols board")
struct SymbolsBoardTests {
  let symbols: SymbolsV1
  let movers: MoversV1

  init() throws {
    symbols = try Wire.decoder().decode(SymbolsV1.self, from: fixture("symbols-v1.json"))
    movers = try Wire.decoder().decode(MoversV1.self, from: fixture("movers-v1.json"))
  }

  @Test("Nine tabs: the eight stages in pipeline order, then the fast movers, each with its count")
  func tabs() {
    #expect(SymbolsTab.all.count == SymbolStage.allCases.count + 1)
    #expect(SymbolsTab.all.last == .fastMovers)
    #expect(SymbolsBoard.count(.stage(.screeners), symbols: symbols, movers: movers) == 412)
    #expect(SymbolsBoard.count(.stage(.quote), symbols: symbols, movers: movers) == 141)
    #expect(SymbolsBoard.count(.fastMovers, symbols: symbols, movers: movers) == 2)
    #expect(SymbolsBoard.count(.fastMovers, symbols: symbols, movers: nil) == nil)
    // A funnel stage opens its tab; reconcile has no symbols.
    #expect(SymbolsTab(PipelineStage.bars) == .stage(.bars))
    #expect(SymbolsTab(PipelineStage.reconcile) == nil)
  }

  @Test("A stage tab lists every symbol that got to it; the filters split passed and dropped there")
  func filters() {
    let rows = symbols.rows
    func names(_ stage: SymbolStage, _ filter: SymbolsFilter) -> [String] {
      SymbolsBoard.rows(rows, stage: stage, filter: filter, sort: .symbol).map(\.symbol)
    }
    #expect(names(.screeners, .all) == ["ABCD", "QRST", "SLOW", "SPY", "WXYZ"])
    #expect(names(.quote, .all) == ["ABCD", "QRST", "SLOW", "WXYZ"])
    #expect(names(.quote, .droppedHere) == ["WXYZ"])
    #expect(names(.quote, .passed) == ["ABCD", "QRST", "SLOW"])
    #expect(names(.universe, .droppedHere) == ["SPY"])
    #expect(names(.strategy, .droppedHere) == ["QRST"])
    #expect(names(.stop, .passed) == ["ABCD"])
    // A search keeps any symbol holding the text, in any case.
    #expect(SymbolsBoard.rows(rows, stage: .screeners, filter: .all, sort: .symbol, search: " s ").map(\.symbol)
      == ["QRST", "SLOW", "SPY"])
  }

  @Test("Sorts: furthest stage, screener rank and change put the missing last")
  func sorts() {
    let rows = symbols.rows
    func names(_ sort: SymbolsSort) -> [String] {
      SymbolsBoard.rows(rows, stage: .screeners, filter: .all, sort: sort).map(\.symbol)
    }
    #expect(names(.furthest) == ["ABCD", "QRST", "SLOW", "WXYZ", "SPY"])
    #expect(names(.rank) == ["SPY", "ABCD", "WXYZ", "QRST", "SLOW"])
    #expect(names(.change) == ["ABCD", "QRST", "SPY", "SLOW", "WXYZ"])
  }

  @Test("An outcome says where the symbol stopped and why, never a bare code")
  func outcomes() throws {
    let rows = Dictionary(uniqueKeysWithValues: symbols.rows.map { ($0.symbol, $0) })
    let abcd = try #require(rows["ABCD"])
    #expect(SymbolsBoard.outcome(abcd).tone == .passed)
    let wxyz = try #require(rows["WXYZ"])
    let spread = SymbolsBoard.checkText(try #require(wxyz.check))
    #expect(SymbolsBoard.outcome(wxyz).text
      == String(localized: L10n.symbolsDropped(String(localized: L10n.symbolStageQuote), spread)))
    #expect(spread.contains("0.0031") && spread.contains("0.002"))
    let spy = try #require(rows["SPY"])
    #expect(SymbolsBoard.reason(spy)
      == "\(String(localized: L10n.discoverySecurityTypeNotAllowed)) · ETF (needs COMMON_STOCK)")
    let slow = try #require(rows["SLOW"])
    #expect(SymbolsBoard.outcome(slow).tone == .notReached)
    #expect(SymbolsBoard.reason(slow) == "bars budget · bars route window full")
  }

  @Test("The path passes every stage before where it stands, then marks it, then the rest ahead")
  func path() throws {
    let wxyz = try #require(symbols.rows.first { $0.symbol == "WXYZ" })
    let steps = SymbolsBoard.path(wxyz)
    #expect(steps.map(\.stage) == SymbolStage.allCases)
    #expect(steps[0].mark == .passed && steps[1].mark == .passed)
    #expect(steps[2].mark == .here(.dropped) && steps[2].detail != nil)
    #expect(steps[3...].allSatisfy { $0.mark == .ahead })
  }

  @Test("A fast mover reads as the design writes it")
  func moverTexts() throws {
    let klmn = try #require(movers.movers.first)
    #expect(SymbolsBoard.volume(klmn) == String(localized: L10n.moverVolume(SymbolsBoard.fixed(13.3, digits: 1))))
    #expect(SymbolsBoard.move(klmn) == String(localized: L10n.moverMove("+" + SymbolsBoard.fixed(4.8, digits: 1))))
    let efgh = try #require(movers.movers.last)
    #expect(SymbolsBoard.move(efgh) == String(localized: L10n.moverMove(SymbolsBoard.fixed(-2.1, digits: 1))))
    #expect(SymbolsBoard.movers(movers.movers, search: "efg").map(\.symbol) == ["EFGH"])
    #expect(!SymbolsBoard.rules(try #require(movers.rules)).isEmpty)
  }

  @Test("The table sorts by a clicked column, missing values last; a second click turns it")
  func tableOrder() {
    let standard = SymbolsOrder.standard(.stage(.screeners))
    #expect(standard == SymbolsOrder(column: .stage, ascending: false))
    let byStage = SymbolsBoard.lines(.stage(.screeners), symbols: symbols, movers: movers, positions: [],
      query: SymbolsQuery(filter: .all, search: "", order: standard))
    #expect(byStage.first?.symbol == "ABCD")  // through the stop
    let byChange = standard.clicked(.change)
    #expect(byChange == SymbolsOrder(column: .change, ascending: false))
    let changes = SymbolsBoard.lines(.stage(.screeners), symbols: symbols, movers: movers, positions: [],
      query: SymbolsQuery(filter: .all, search: "", order: byChange))
    #expect(changes.first?.symbol == "ABCD")
    #expect(changes.last?.row?.changePct == nil)  // WXYZ has no change: last either way
    let turned = SymbolsBoard.lines(.stage(.screeners), symbols: symbols, movers: movers, positions: [],
      query: SymbolsQuery(filter: .all, search: "", order: byChange.clicked(.change)))
    #expect(turned.last?.row?.changePct == nil)
    #expect(byChange.clicked(.symbol) == SymbolsOrder(column: .symbol, ascending: true))
  }

  @Test("Fast movers: positions and watches without a bar are pinned on top; the rest by |ATR|")
  func fastMoverLines() {
    let lines = SymbolsBoard.lines(.fastMovers, symbols: symbols, movers: movers, positions: ["QRST"],
      query: SymbolsQuery(filter: .all, search: "", order: .standard(.fastMovers)))
    #expect(lines.map(\.symbol) == ["QRST", "KLMN", "EFGH"])
    #expect(lines.first?.mover == nil && lines.first?.position == true)
  }

  @Test("Table cells read as the design writes them")
  func tableCells() throws {
    let klmn = try #require(movers.movers.first)
    #expect(SymbolsBoard.ratio(klmn.volumeRatio) == String(localized: L10n.symbolsRatio(SymbolsBoard.fixed(13.3, digits: 1))))
    let efgh = try #require(movers.movers.last)
    #expect(SymbolsBoard.atr(efgh.moveAtr).hasPrefix(SymbolsBoard.minus))
    let abcd = try #require(symbols.rows.first { $0.symbol == "ABCD" })
    #expect(SymbolsBoard.screenerCell(abcd)?.more == String(localized: L10n.symbolsMore(1)))
    #expect(abcd.reached.count == SymbolStage.allCases.count)
    #expect(abcd.checks.count == 2 && abcd.strategy != nil)
    #expect(SymbolsBoard.why(abcd) == nil)  // passed
    let qrst = try #require(symbols.rows.first { $0.symbol == "QRST" })
    #expect(SymbolsBoard.why(qrst) == SymbolsBoard.reason(qrst))
  }

  @Test("The day line measures against the previous close behind the price and its change")
  func dayLinePreviousClose() throws {
    let previous = SymbolDayLine.previousClose(price: try DecimalString("11"), changePct: try DecimalString("10"))
    #expect(previous == 10)
    #expect(SymbolDayLine.previousClose(price: nil, changePct: try DecimalString("10")) == nil)
    #expect(SymbolDayLine.previousClose(price: try DecimalString("11"), changePct: try DecimalString("-100")) == nil)
    let plotted = SymbolDayLine(closes: [10, 11], previousClose: 10).plotted
    #expect(plotted.closes == [10, 11] && plotted.previousClose == 10)
  }
}
