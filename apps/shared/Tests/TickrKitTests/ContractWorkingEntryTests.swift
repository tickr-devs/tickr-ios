import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: own entries working at the broker with nothing filled yet (Cancel entry)")
struct ContractWorkingEntryTests {
  @Test func workingEntryDecodes() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self,
      from: fixture("status-response-v1.working-entry.json"))
    let entry = try #require(response.status?.workingEntries.first)
    #expect(entry.symbol == "KLMN")
    #expect(entry.quantity.text == "15")
    #expect(entry.limitPrice.text == "9.02")
    #expect(entry.stopPrice.text == "8.78")
    #expect(entry.plannedLossUsd.text == "3.60")
    #expect(entry.entry.sentAt != nil)
    #expect(!entry.cancelRequested)
  }

  @Test func anOlderBotListsNone() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    #expect(response.status?.workingEntries.isEmpty == true)
  }
}
