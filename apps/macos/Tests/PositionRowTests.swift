import Foundation
import Testing
import TickrDesign
@testable import TickrKit
@testable import TickrScreens

@Suite("An open position's price and R, fresh or as of the newest bar")
struct PositionRowTests {
  @Test("A stale bar keeps the current figures empty but still gives R as of that bar")
  func staleBar() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let close = position.entryPrice.value
    let stale = PositionRow(position: position, lastBarClose: nil, lastBarAt: Date(), closes: [], latestClose: close)
    #expect(stale.resultR == nil)
    #expect(stale.unrealized == nil)
    #expect(stale.latestResultR == Risk.multiple(entry: stale.entry, stop: stale.stop, price: close))
    let fresh = PositionRow(position: position, lastBarClose: close, lastBarAt: Date(), closes: [], latestClose: close)
    #expect(fresh.resultR == fresh.latestResultR)
  }

  @Test("In the trades table a stale open position shows its figures as of that bar, greyed")
  func staleTradeRow() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let close = position.entryPrice.value + 1
    let stale = TradeRow.open(
      PositionRow(position: position, lastBarClose: nil, lastBarAt: Date(), closes: [], latestClose: close))
    #expect(stale.isStale)
    #expect(stale.result != nil)
    #expect(stale.resultR != nil)
    #expect(stale.resultRColor == Palette.textQuaternary)
    let fresh = TradeRow.open(
      PositionRow(position: position, lastBarClose: close, lastBarAt: Date(), closes: [], latestClose: close))
    #expect(!fresh.isStale)
    #expect(fresh.resultRColor == Palette.result(try #require(fresh.resultR)))
  }
}

@Suite("When the newest captured bar is still the current price")
@MainActor
struct BarCurrentTests {
  /// The server's `status_stale_seconds` in these tests.
  static let stale: TimeInterval = 15

  @Test("Current until the next bar is overdue: one bar plus the stale allowance after its close")
  func window() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let close = start.addingTimeInterval(AppModel.barSeconds)
    let lastCurrent = close.addingTimeInterval(AppModel.barSeconds + Self.stale)
    #expect(AppModel.barIsCurrent(start: start, now: close, staleSeconds: Self.stale))
    // Mid-way to the next bar's close, the newest completed bar is still the current one.
    #expect(AppModel.barIsCurrent(start: start, now: close.addingTimeInterval(AppModel.barSeconds / 2),
      staleSeconds: Self.stale))
    #expect(AppModel.barIsCurrent(start: start, now: lastCurrent, staleSeconds: Self.stale))
    #expect(!AppModel.barIsCurrent(start: start, now: lastCurrent.addingTimeInterval(1), staleSeconds: Self.stale))
  }

  @Test("An old bar still gives a result, greyed, instead of a blank")
  func staleResult() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let close = position.entryPrice.value + 1
    let stale = PositionRow(position: position, lastBarClose: nil, lastBarAt: Date(), closes: [], latestClose: close)
    #expect(stale.isStale)
    #expect(stale.unrealized == nil)
    #expect(stale.latestUnrealized == position.quantity.value)
    let fresh = PositionRow(position: position, lastBarClose: close, lastBarAt: Date(), closes: [], latestClose: close)
    #expect(!fresh.isStale)
    #expect(fresh.unrealized == fresh.latestUnrealized)
  }

  @Test("The live bid is the price over any bar: result, R and the line follow it, and it is never stale")
  func livePrice() throws {
    let position = try #require(try fixture(StatusResponseV1.self, "status-response-v1.json").status?.position)
    let quotes = try fixture(QuotesResponseV1.self, "quotes-response-v1.json")
    let quote = try #require(quotes.quotes.quotes.first)
    let live = try #require(LivePrice(quote: quote, now: quote.quotedAt.date, maxAgeSeconds: 60))
    let close = position.entryPrice.value
    let row = PositionRow(position: position, lastBarClose: nil, lastBarAt: Date(), closes: [close],
      latestClose: close, live: live)
    #expect(row.price == live.bid)
    #expect(!row.isStale)
    #expect(row.unrealized == (live.bid - row.entry) * row.quantity)
    #expect(row.resultR == Risk.multiple(entry: row.entry, stop: row.stop, price: live.bid))
    #expect(row.line == [close, live.bid])
  }
}
