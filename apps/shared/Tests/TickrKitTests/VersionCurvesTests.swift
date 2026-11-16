import Foundation
import Testing
@testable import TickrKit

@Suite("Running result of each strategy version")
struct VersionCurvesTests {
  static let base = Date(timeIntervalSince1970: 1_794_841_200)

  func close(_ minute: Double, _ result: String?) -> (at: Date, result: Decimal?) {
    (at: Self.base.addingTimeInterval(minute * 60), result: result.flatMap { Decimal(string: $0) })
  }

  @Test("Results add up in close order, whatever order they come in")
  func running() {
    let curve = VersionCurve.make(name: "a", version: "1", observer: true,
      closes: [close(30, "-5"), close(10, "12.5"), close(20, "-2.5")], truncated: false)
    #expect(curve.points.map(\.total) == [12.5, 10, 5])
    #expect(curve.total == 5)
  }

  @Test("A day without closed trades is a flat zero")
  func empty() {
    let curve = VersionCurve.make(name: "a", version: "1", observer: false, closes: [], truncated: false)
    #expect(curve.points.isEmpty)
    #expect(curve.total == 0)
  }

  @Test("A trade without a result or a cut list leaves the line without a total")
  func incomplete() {
    let missing = VersionCurve.make(name: "a", version: "1", observer: true,
      closes: [close(10, "3"), close(20, nil)], truncated: false)
    #expect(missing.points.count == 1)
    #expect(missing.total == nil)
    let cut = VersionCurve.make(name: "a", version: "1", observer: true, closes: [close(10, "3")], truncated: true)
    #expect(cut.total == nil)
  }

  func trade(_ close: String?, _ result: String?) -> String {
    """
    {"symbol": "MVLD", "at": "2026-11-16T15:00:00.000Z", "opened_at": null, "entry_price": null,
     "closed_at": \(close.map { "\"\($0)\"" } ?? "null"), "exit_price": null, "quantity": null, "exit_reason": null,
     "result_gross_usd": \(result.map { "\"\($0)\"" } ?? "null"), "result_r": null, "cause": null}
    """
  }

  func observer(_ trades: [String], result: String?, truncated: Bool = false) throws -> ObserverV1 {
    let json = """
      {"name": "price-action", "version": "2", "decisions": [],
       "result_gross_usd": \(result.map { "\"\($0)\"" } ?? "null"),
       "result_cause": \(result == nil ? "\"no bars\"" : "null"),
       "trades": [\(trades.joined(separator: ","))], "trades_cause": null, "trades_truncated": \(truncated)}
      """
    return try Wire.decoder().decode(ObserverV1.self, from: Data(json.utf8))
  }

  @Test("An observer's line skips entries that never closed and reports the bot's own total")
  func simulated() throws {
    let curve = try #require(VersionCurve.simulated(try observer([
      trade("2026-11-16T15:20:00.000Z", "4.25"), trade(nil, nil), trade("2026-11-16T15:10:00.000Z", "3.255"),
    ], result: "7.51")))
    #expect(curve.points.map(\.total) == [Decimal(string: "3.255")!, Decimal(string: "7.505")!])
    #expect(curve.total == Decimal(string: "7.51"))
    #expect(try VersionCurve.simulated(try observer([], result: nil))?.total == nil)
    #expect(try VersionCurve.simulated(try observer([], result: "0", truncated: true))?.total == nil)
  }

  @Test("The trading strategy's total is the bot's day result, not the sum of the listed trades")
  func activeTotal() throws {
    let response = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    let status = try #require(response.status)
    let reported = try #require(Decimal(string: "123.45"))
    let curve = VersionCurve.active(name: "price-action", version: "1", trades: status.tradesToday, total: reported)
    #expect(curve.points.count == status.tradesToday.count)
    #expect(curve.points.last?.total == status.tradesToday.map(\.resultUsd.value).reduce(0, +))
    #expect(curve.total == reported)
  }
}
