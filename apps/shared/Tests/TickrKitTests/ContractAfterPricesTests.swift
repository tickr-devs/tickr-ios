import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: prices after and the skipped what-if")
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
}
