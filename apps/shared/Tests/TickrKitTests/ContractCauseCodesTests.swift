import Foundation
import Testing
@testable import TickrKit

@Suite("Contract: codes of the API's own causes")
struct ContractCauseCodesTests {
  @Test func performanceExclusion() throws {
    let performance = try Wire.decoder().decode(PerformanceV1.self, from: fixture("performance-v1.json"))
    #expect(performance.exclusions.first?.causeCodes.first?.code == "planned_loss_not_positive_r")
  }

  @Test("A cause and its codes come together: none without a cause")
  func observers() throws {
    let observers = try Wire.decoder().decode(ObserversV1.self, from: fixture("observers-v1.json")).observers
    for observer in observers {
      #expect(observer.resultCause == nil ? observer.resultCauseCodes.isEmpty : !observer.resultCauseCodes.isEmpty)
      #expect(observer.tradesCause == nil ? observer.tradesCauseCodes.isEmpty : !observer.tradesCauseCodes.isEmpty)
    }
  }

  /// A version the Lab cannot replay, and a failed run, read in the person's words.
  @Test func labReplay() throws {
    let idle = try Wire.decoder().decode(LabReplayV1.self, from: fixture("lab-replay-v1.idle.json"))
    let refused = try #require(idle.versions.first { $0.cause != nil })
    #expect(refused.causeCodes.first?.code == "strategy_without_name")
    #expect(refused.causeText != refused.cause)
    let failed = try Wire.decoder().decode(LabReplayV1.self, from: fixture("lab-replay-v1.failed.json"))
    #expect(failed.causeCodes.first?.code == "backtest_refused")
  }

  /// The session's close is known from the document: a start waits for it, and not after it.
  @Test func labReplayWaitsForTheClose() throws {
    let idle = try Wire.decoder().decode(LabReplayV1.self, from: fixture("lab-replay-v1.idle.json"))
    #expect(idle.waitsUntil(now: .now) == nil)
    var json = try #require(try JSONSerialization.jsonObject(with: fixture("lab-replay-v1.idle.json")) as? [String: Any])
    json["available_at"] = "2026-11-16T21:00:00.000Z"
    let waiting = try Wire.decoder().decode(LabReplayV1.self, from: JSONSerialization.data(withJSONObject: json))
    let close = try #require(waiting.availableAt?.date)
    #expect(waiting.waitsUntil(now: close.addingTimeInterval(-1)) == close)
    #expect(waiting.waitsUntil(now: close) == nil)
  }

  @Test("A document written before codes reads with none")
  func older() throws {
    let json = #"{"minutes": 1, "at": "2026-11-16T15:01:00.000Z", "price": null, "change_usd": null, "cause": "x"}"#
    let price = try Wire.decoder().decode(PriceAfterV1.self, from: Data(json.utf8))
    #expect(price.causeCodes.isEmpty)
  }
}
