import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: prices after, the skipped what-if and observer trades")
struct ContractAfterPricesTests {
  @Test func pricesAfterAndWhatIf() throws {
    let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
    let trade = try #require(day.trades.first)
    #expect(trade.pricesAfter.map(\.minutes) == [1, 5, 15, 60])
    #expect(trade.pricesAfter[2].price == nil)
    #expect(trade.pricesAfter[2].cause != nil)
    #expect(trade.overshootUsd?.text == "0.24")
    let skipped = try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json"))
    #expect(skipped.signals.map(\.whatIf.exitReason) == [.stop, .flatten, nil])
    #expect(skipped.signals.last?.whatIf.cause != nil)
    #expect(skipped.signals.last?.pricesAfter.isEmpty == true)
  }

  @Test func observerTrades() throws {
    let observers = try Wire.decoder().decode(ObserversV1.self, from: fixture("observers-v1.json"))
    let trades = try #require(observers.observers.first?.trades)
    #expect(trades.first?.exitReason == .stop)
    #expect(trades.first?.resultR?.text == "-1.0333")
    #expect(trades.dropFirst().first?.entryPrice == nil)
    #expect(trades.dropFirst().first?.cause != nil)
    #expect(observers.observers.last?.trades == nil)
    #expect(observers.observers.last?.tradesCause != nil)
  }
}
