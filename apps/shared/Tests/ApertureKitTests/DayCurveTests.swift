@testable import ApertureKit
import Foundation
import Testing

@Suite("Day curves: a version's result through the day")
struct DayCurveTests {
  @Test("Closes add up in time order; the line ends at the reported result")
  func steps() {
    let t0 = Date(timeIntervalSince1970: 1_000)
    let curve = DayCurve(
      closes: [(t0.addingTimeInterval(60), -2), (t0, 5)], reported: Decimal(string: "2.5"), complete: true)
    #expect(curve.steps.map(\.total) == [5, 3])
    #expect(curve.steps.first?.at == t0)
    #expect(curve.end == Decimal(string: "2.5"))
    #expect(DayCurve(closes: [(t0, 5)], reported: nil, complete: true).end == 5)
  }

  @Test("Observers: simulated trades without a result add nothing; no trades, no curve")
  func observers() throws {
    let observers = try Wire.decoder().decode(ObserversV1.self, from: fixture("observers-v1.json")).observers
    let first = try #require(observers.first)
    let curve = try #require(DayCurve.observer(first))
    let results = try #require(first.trades).compactMap(\.resultGrossUsd?.value)
    #expect(curve.steps.count == results.count)
    #expect(curve.complete == !first.tradesTruncated)
    #expect(DayCurve.observer(try #require(observers.last)) == nil)
  }
}
