@testable import ApertureKit
import Foundation
import Testing

@Suite("Observer summaries for the Lab")
struct ObserverSummaryTests {
  func observer(
    _ decisions: [(symbol: String, action: String)],
    result: String? = nil,
    cause: String? = nil
  ) throws -> ObserverV1 {
    let list = decisions.map {
      #"{"at": "2026-11-16T15:00:00.000Z", "symbol": "\#($0.symbol)", "action": "\#($0.action)", "reasons": []}"#
    }
    let json = """
      {"name": "price-action", "version": "2", "decisions": [\(list.joined(separator: ","))],
       "result_gross_usd": \(result.map { "\"\($0)\"" } ?? "null"),
       "result_cause": \(cause.map { "\"\($0)\"" } ?? "null")}
      """
    return try Wire.decoder().decode(ObserverV1.self, from: Data(json.utf8))
  }

  @Test("Entered symbols once each, agreement with the bot's trades, exits and result")
  func summary() throws {
    let summary = ObserverSummary(try observer([("MVLD", "ENTER"), ("MVLD", "ENTER"), ("BXVR", "WATCH"),
      ("HLQN", "ENTER"), ("MVLD", "EXIT")], result: "-12.50"), traded: ["MVLD", "ZZZZ"])
    #expect(summary.entered == ["MVLD", "HLQN"])
    #expect(summary.shared == ["MVLD"])
    #expect(summary.agreement == 0.5)
    #expect(summary.exits == 1)
    #expect(summary.result == Decimal(string: "-12.50"))
    #expect(summary.resultCause == nil)
    #expect(summary.id == "price-action 2")
  }

  @Test("No entries: agreement unknown, never zero; a missing result keeps its cause")
  func nothing() throws {
    let summary = ObserverSummary(try observer([("BXVR", "WATCH")], cause: "no bars for BXVR"), traded: ["MVLD"])
    #expect(summary.agreement == nil)
    #expect(summary.result == nil)
    #expect(summary.resultCause == "no bars for BXVR")
  }
}
