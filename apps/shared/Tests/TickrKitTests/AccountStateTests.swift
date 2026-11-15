import Foundation
import Testing
@testable import TickrKit

@Suite struct AccountStateTests {
  func response(_ text: String) throws -> AccountResponseV1 {
    try Wire.decoder().decode(AccountResponseV1.self, from: Data(text.utf8))
  }

  func fixtureText() throws -> String {
    try #require(String(data: try fixture("account-response-v1.json"), encoding: .utf8))
  }

  /// A later read of the same account changes only its times: no new state.
  @Test func laterReadOfTheSameAccountKeepsItsState() throws {
    let text = try fixtureText()
    let later = text
      .replacingOccurrences(of: "\"served_at\": \"2026-11-16T15:00:04.123Z\"",
        with: "\"served_at\": \"2026-11-16T15:00:09.123Z\"")
      .replacingOccurrences(of: "\"read_at\": \"2026-11-16T15:00:00.123Z\"",
        with: "\"read_at\": \"2026-11-16T15:00:05.123Z\"")
      .replacingOccurrences(of: "\"age_seconds\": \"4.000\"", with: "\"age_seconds\": \"5.000\"")
    let first = try response(text)
    let second = try response(later)
    #expect(first != second)
    #expect(first.state == second.state)
  }

  @Test func staleAccountIsANewState() throws {
    let text = try fixtureText()
    let stale = text.replacingOccurrences(of: "\"stale\": false", with: "\"stale\": true")
    #expect(try response(text).state != response(stale).state)
  }
}
