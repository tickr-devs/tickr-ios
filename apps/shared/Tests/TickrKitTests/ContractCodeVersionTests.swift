import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: the bot code version of each trade and of the running bot")
struct ContractCodeVersionTests {
  static let full = "6c4eec8b0f3a91d2e5b7c6a8d9e0f1a2b3c4d5e6"

  @Test func dayTrades() throws {
    let day = try Wire.decoder().decode(DayV1.self, from: fixture("day-v1.json"))
    #expect(day.trades.first?.codeVersion == Self.full)
    #expect(day.trades.dropFirst().first?.codeVersion == nil)
  }

  @Test func statusAndItsTrades() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    #expect(response.status?.codeVersion == Self.full + CodeVersion.dirtySuffix)
    #expect(response.status?.tradesToday.first?.codeVersion == Self.full + CodeVersion.dirtySuffix)
    let minimal = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.minimal.json"))
    #expect(minimal.status?.codeVersion == nil)
  }

  @Test func shortFormKeepsTheDirtyMark() {
    #expect(CodeVersion.short(Self.full) == "6c4eec8b")
    #expect(CodeVersion.short(Self.full + CodeVersion.dirtySuffix) == "6c4eec8b-dirty")
    #expect(CodeVersion.short("abc1234") == "abc1234")
  }
}
