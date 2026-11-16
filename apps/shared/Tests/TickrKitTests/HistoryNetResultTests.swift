import Foundation
import Testing
@testable import TickrKit

/// The history documents' result after fees (`result_net_usd`, added after version 1 shipped):
/// decoded when present, absent in older documents, and preferred over the gross when shown.
@Suite("History: the result after fees")
struct HistoryNetResultTests {
  /// A contract fixture as a JSON object, with `result_net_usd` set on the document (or each
  /// day), on each trade, or removed everywhere when the value is nil.
  func document(_ name: String, net: String?, tradeNets: [String?] = []) throws -> Data {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
    func apply(_ value: String?, _ item: inout [String: Any]) {
      item["result_net_usd"] = value
    }
    if var days = object["days"] as? [[String: Any]] {
      for index in days.indices { apply(net, &days[index]) }
      object["days"] = days
    } else {
      apply(net, &object)
    }
    if var trades = object["trades"] as? [[String: Any]] {
      for index in trades.indices { apply(index < tradeNets.count ? tradeNets[index] : nil, &trades[index]) }
      object["trades"] = trades
    }
    return try JSONSerialization.data(withJSONObject: object)
  }

  func usd(_ text: String) throws -> Decimal { try DecimalString(text).value }

  @Test("A day document without the field decodes, and its trades and total show the gross")
  func dayWithoutNet() throws {
    let day = try Wire.decoder().decode(DayV1.self, from: document("day-v1.json", net: nil))
    #expect(day.resultNetUsd == nil)
    #expect(day.resultUsd == day.resultGrossUsd)
    #expect(day.trades.allSatisfy { $0.resultNetUsd == nil && $0.resultUsd == $0.resultGrossUsd })
  }

  @Test("A day document with the field shows the result after fees for the day and each trade")
  func dayWithNet() throws {
    let data = try document("day-v1.json", net: "2.38", tradeNets: ["-1.66", "4.04"])
    let day = try Wire.decoder().decode(DayV1.self, from: data)
    #expect(day.resultNetUsd?.value == Decimal(string: "2.38"))
    #expect(day.resultUsd.value == Decimal(string: "2.38"))
    #expect(day.resultGrossUsd.value == Decimal(string: "2.50"))
    #expect(day.trades.map(\.resultUsd.value) == [try usd("-1.66"), try usd("4.04")])
    #expect(day.trades.map(\.resultGrossUsd.value) == [try usd("-1.60"), try usd("4.10")])
  }

  @Test("A trade whose fees are not recorded keeps its gross next to one that has them")
  func mixedTrades() throws {
    let day = try Wire.decoder().decode(DayV1.self, from: document("day-v1.json", net: nil, tradeNets: [nil, "4.04"]))
    #expect(day.trades.map(\.resultUsd.value) == [try usd("-1.60"), try usd("4.04")])
    #expect(day.resultUsd == day.resultGrossUsd)
  }

  @Test("A days list with and without the field decodes; a summary shows the net when present")
  func daysList() throws {
    let without = try Wire.decoder().decode(DaysV1.self, from: document("days-v1.json", net: nil))
    #expect(without.days.allSatisfy { $0.resultNetUsd == nil && $0.resultUsd == $0.resultGrossUsd })
    let with = try Wire.decoder().decode(DaysV1.self, from: document("days-v1.json", net: "-3.21"))
    #expect(with.days.allSatisfy { $0.resultUsd.value == Decimal(string: "-3.21") })
  }

  @Test("A recorded day's stats show the net and are no longer before fees once it is known")
  func dayStats() throws {
    let without = try Wire.decoder().decode(DaysV1.self, from: document("days-v1.json", net: nil))
    let traded = try #require(without.days.first { $0.trades > 0 })
    #expect(Board.dayStats(traded).beforeFees)
    #expect(Board.dayStats(traded).resultUsd == traded.resultGrossUsd.value)
    let with = try Wire.decoder().decode(DaysV1.self, from: document("days-v1.json", net: "2.38"))
    let netDay = try #require(with.days.first { $0.trades > 0 })
    #expect(!Board.dayStats(netDay).beforeFees)
    #expect(Board.dayStats(netDay).resultUsd == Decimal(string: "2.38"))
  }

  @Test("The field round-trips as written, null included")
  func roundTripsNull() throws {
    let data = try document("day-v1.json", net: "2.38", tradeNets: ["-1.66"])
    let (original, again) = try roundTrip(DayV1.self, data)
    let originalTrades = (original as? [String: Any])?["trades"] as? [[String: Any]]
    let againTrades = (again as? [String: Any])?["trades"] as? [[String: Any]]
    #expect((againTrades?.last?["result_net_usd"]) is NSNull)
    #expect(originalTrades?.count == againTrades?.count)
    #expect((again as? [String: Any])?["result_net_usd"] as? String == "2.38")
  }
}
