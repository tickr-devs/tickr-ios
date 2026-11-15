import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: the strategy that opened each trade")
struct ContractTradeStrategyTests {
  @Test func dayTrades() throws {
    let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
    #expect(day.trades.first?.strategy?.name == "price-action-v1")
    #expect(day.trades.first?.strategy?.version == "1")
    #expect(day.trades.dropFirst().first?.strategy == nil)
  }

  @Test func statusTrades() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    #expect(response.status?.tradesToday.first?.strategy?.name == "price-action-v1")
  }
}
