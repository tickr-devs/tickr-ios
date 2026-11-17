import Foundation
import Testing
@testable import TickrKit

@Suite struct DayChangeTests {
  /// The day's change is measured from the previous close the screener row implies, never from
  /// the day's first open (iOS showed −19.5% for a stock up 160% that had opened higher).
  @Test func fromThePreviousClose() throws {
    let flow = try Wire.decoder().decode(FlowV1.self, from: fixture("flow-v1.json"))
    // ABCD: 4.12 at +12.40%.
    let previous = try #require(DayChange.previousClose("ABCD", flow: flow))
    #expect(previous == Decimal(string: "4.12")! * 100 / Decimal(string: "112.40")!)
    let price = try #require(Decimal(string: "4.12"))
    #expect(DayChange.fraction(price: price, previousClose: previous) == price / previous - 1)
    // No change without a screener row or a price on it.
    #expect(DayChange.previousClose("NONE", flow: flow) == nil)
    #expect(DayChange.previousClose("SPY", flow: flow) == nil)
    #expect(DayChange.fraction(price: 1, previousClose: nil) == nil)
    #expect(DayChange.fraction(price: 1, previousClose: 0) == nil)
  }

  /// Settings are read again when the API restarted (a new release), not only once per launch.
  @Test func settingsReadAgainAfterAnAPIRestart() throws {
    let status = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.json"))
    let settings = try Wire.decoder().decode(SettingsV1.self, from: fixture("settings-v1.json"))
    let started = try #require(status.apiStartedAt)
    #expect(status.needsSettings(nil, readFor: started))
    #expect(!status.needsSettings(settings, readFor: started))
    #expect(status.needsSettings(settings, readFor: nil))
  }
}
