@testable import ApertureKit
import Foundation
import Testing

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

  @Test("A document written before codes reads with none")
  func older() throws {
    let json = #"{"minutes": 1, "at": "2026-11-16T15:01:00.000Z", "price": null, "change_usd": null, "cause": "x"}"#
    let price = try Wire.decoder().decode(PriceAfterV1.self, from: Data(json.utf8))
    #expect(price.causeCodes.isEmpty)
  }
}
