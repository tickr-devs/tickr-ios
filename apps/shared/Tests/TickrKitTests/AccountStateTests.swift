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

  @Test func accountValues() throws {
    let fresh = try Wire.decoder().decode(AccountResponseV1.self, from: fixture("account-response-v1.json"))
    #expect(!fresh.stale)
    #expect(fresh.account.matchesRecords)
    #expect(fresh.account.mismatch == nil)
    let balances = try #require(fresh.account.balances)
    #expect(balances.equityUsd.text == "100123.40")
    #expect(balances.buyingPowerUsd.text == "400493.60")
    #expect(balances.dayPlUsd.text == "-1.00")
    #expect(balances.marginCalls == 0)
    #expect(balances.dayTradesLeft == nil)
    #expect(fresh.account.accountLabel == "Individual Margin")
    #expect(fresh.account.orders.first?.stopPrice?.text == "11.90")
    let stale = try Wire.decoder().decode(AccountResponseV1.self, from: fixture("account-response-v1.stale.json"))
    #expect(stale.stale)
    #expect(!stale.account.matchesRecords)
    #expect(stale.account.positions.last?.avgPrice == nil)
    #expect(stale.account.orders.map(\.ours) == [true, false])
    #expect(stale.account.orders.last?.limitPrice?.text == "19.80")
    #expect(stale.account.balances == nil)
    #expect(stale.account.accountLabel == nil)
  }

  /// A file from a bot older than the balance read has none of its keys: no balances, no error.
  @Test func olderBotFileHasNoBalances() throws {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("account-response-v1.json")) as? [String: Any])
    var account = try #require(object["account"] as? [String: Any])
    for key in [
      "balance_read_at", "cash_usd", "positions_value_usd", "unrealized_pl_usd", "day_pl_usd",
      "overnight_buying_power_usd", "maintenance_margin_usd", "margin_calls", "day_trades_left", "account_label",
    ] {
      account.removeValue(forKey: key)
    }
    object["account"] = account
    let decoded = try Wire.decoder().decode(AccountResponseV1.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded.account.balances == nil)
    #expect(decoded.account.accountLabel == nil)
  }
}
