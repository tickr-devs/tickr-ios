import Foundation
import Testing

@testable import TickrKit

@Suite("Symbols in plain words")
struct SymbolsWordsTests {
  let symbols: SymbolsV1
  let movers: MoversV1

  init() throws {
    symbols = try Wire.decoder().decode(SymbolsV1.self, from: fixture("symbols-v1.json"))
    movers = try Wire.decoder().decode(MoversV1.self, from: fixture("movers-v1.json"))
  }

  func row(_ symbol: String) throws -> SymbolRowV1 {
    try #require(symbols.rows.first { $0.symbol == symbol })
  }

  @Test("Each tab has a one-line caption; the decision tab counts the chosen of the decided")
  func captions() {
    #expect(SymbolsBoard.caption(.stage(.screeners), symbols: symbols)
      == String(localized: L10n.symbolsCaptionScreeners))
    #expect(SymbolsBoard.caption(.stage(.strategy), symbols: symbols)
      == String(localized: L10n.symbolsCaptionDecision(6, 37)))
    #expect(SymbolsBoard.caption(.stage(.strategy), symbols: nil) == String(localized: SymbolStage.strategy.title))
    #expect(SymbolsBoard.caption(.fastMovers, symbols: symbols) == String(localized: L10n.symbolsCaptionFast))
  }

  @Test("A line's short reason names the rule or cause without its values; the steps keep them")
  func shortReasons() throws {
    let abcd = try row("ABCD")
    #expect(SymbolsBoard.shortWhy(abcd) == nil)
    let wxyz = try row("WXYZ")
    #expect(SymbolsBoard.shortWhy(wxyz) == ApiText.rule("spread_ratio"))
    #expect(SymbolsBoard.shortWhy(wxyz)?.contains("0.0031") == false)
    let spy = try row("SPY")
    #expect(SymbolsBoard.shortWhy(spy) == String(localized: L10n.discoverySecurityTypeNotAllowed))
    let slow = try row("SLOW")
    #expect(SymbolsBoard.shortWhy(slow) == SymbolsBoard.reason(slow))
    let here = try #require(SymbolsBoard.path(wxyz).first { $0.stage == .quote })
    #expect(here.detail == SymbolsBoard.reason(wxyz))
  }

  @Test("Outcomes: Entered, Skipped by the decision, Dropped elsewhere, Not reached")
  func outcomes() throws {
    #expect(SymbolsOutcome(try row("ABCD")) == .passed)
    #expect(SymbolsOutcome(try row("QRST")) == .skipped)
    #expect(SymbolsOutcome(try row("WXYZ")) == .dropped)
    #expect(SymbolsOutcome(try row("SLOW")) == .notReached)
  }

  @Test("The headline is one word and one caption: where it stands and why, or its stop")
  func headlines() throws {
    let abcd = SymbolsBoard.headline(try row("ABCD"))
    #expect(String(localized: abcd.title) == String(localized: L10n.symbolsOutcomePassed))
    #expect(abcd.caption == String(localized: L10n.symbolsPassedDetail))
    let qrst = try row("QRST")
    let skipped = SymbolsBoard.headline(qrst)
    #expect(String(localized: skipped.title) == String(localized: L10n.symbolsOutcomeSkipped))
    #expect(skipped.caption.contains(String(localized: SymbolStage.strategy.title)))
  }

  @Test("The screeners that found a symbol, best rank first, on its first step")
  func foundBy() throws {
    let abcd = try row("ABCD")
    let found = try #require(SymbolsBoard.foundBy(abcd))
    #expect(found == [
      String(localized: L10n.symbolsSource(String(localized: L10n.symbolsScreenerGainers), 3)),
      String(localized: L10n.symbolsSource(String(localized: L10n.symbolsScreenerActives), 11)),
    ].joined(separator: SymbolsBoard.listSeparator))
    #expect(SymbolsBoard.path(abcd).first?.detail == found)
    #expect(SymbolsBoard.stepsPassed(abcd) == SymbolStage.allCases.count)
    #expect(SymbolsBoard.stepsPassed(try row("WXYZ")) == 2)
  }

  @Test("A fast mover names only the signals that fired")
  func firedSignals() throws {
    let efgh = try #require(movers.movers.first { $0.symbol == "EFGH" })
    #expect(SymbolsBoard.firedSignals(efgh) == [
      String(localized: L10n.symbolsFiredVolume(SymbolsBoard.ratio(efgh.volumeRatio))),
      String(localized: L10n.symbolsFiredMove(SymbolsBoard.atr(efgh.moveAtr))),
    ])
    #expect(!SymbolsBoard.fastRule(try #require(movers.rules)).isEmpty)
  }

  @Test("The Mac table shows the fast bar's figures only on the Fast movers tab, never the screener")
  func tableColumns() {
    #expect(!SymbolsColumn.table(fastMovers: false).contains(.volume))
    #expect(SymbolsColumn.table(fastMovers: true).contains(.atr))
    #expect(!SymbolsColumn.table(fastMovers: true).contains(.screener))
  }
}
