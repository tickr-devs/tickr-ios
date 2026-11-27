import Foundation
import Testing
@testable import TickrKit

/// The Live Activity's content-state as the bot pushes it (docs/api.md, "Live Activity").
@Suite struct LiveActivityTests {
  typealias State = TickrActivityAttributes.ContentState

  static let open = """
    {"state": "open", "day_pnl_cents": 1540, "positions": [
      {"symbol": "ABCD", "last": "12.48", "stop": "11.90", "target": null, "unrealized_cents": 210},
      {"symbol": "KLMN", "last": "0.4567", "stop": "0.4012", "target": "0.5000", "unrealized_cents": -150}],
     "stops_confirmed_at": 1763305200, "reason_code": null, "alarm_symbol": null}
    """
  static let alarm = """
    {"state": "alarm", "day_pnl_cents": -1430, "positions": [
      {"symbol": "ABCD", "last": null, "stop": null, "target": null, "unrealized_cents": null}],
     "stops_confirmed_at": null, "reason_code": "unprotected_timeout", "alarm_symbol": "ABCD"}
    """

  func decode(_ text: String) throws -> State {
    try JSONDecoder().decode(State.self, from: Data(text.utf8))
  }

  @Test func decodesPricesAsDecimalsAndCentsAsDollars() throws {
    let state = try decode(Self.open)
    #expect(state.state == .open)
    #expect(state.dayResult == Decimal(string: "15.4"))
    #expect(state.stopsConfirmed == Date(timeIntervalSince1970: 1_763_305_200))
    #expect(state.reasonCode == nil && state.alarmSymbol == nil)
    let abcd = state.positions[0]
    #expect(abcd.last == Decimal(string: "12.48") && abcd.stop == Decimal(string: "11.90"))
    #expect(abcd.target == nil && abcd.progress == nil)
    #expect(abcd.unrealized == Decimal(string: "2.1"))
    let klmn = state.positions[1]
    #expect(klmn.unrealized == Decimal(string: "-1.5"))
    let progress = try #require(klmn.progress)
    #expect(abs(progress - 0.0555 / 0.0988) < 0.0001)
  }

  @Test func decodesNulls() throws {
    let state = try decode(Self.alarm)
    #expect(state.state == .alarm && state.alarmSymbol == "ABCD" && state.reasonCode == "unprotected_timeout")
    #expect(state.stopsConfirmed == nil)
    let position = state.positions[0]
    #expect(position.last == nil && position.stop == nil && position.unrealized == nil && position.progress == nil)
  }

  @Test func encodesWhatItDecodes() throws {
    for text in [Self.open, Self.alarm] {
      let state = try decode(text)
      let again = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(state))
      #expect(again == state)
    }
  }

  @Test(arguments: ["\"closing\"", "\"OPEN\"", "null"])
  func refusesAStateItDoesNotKnow(_ state: String) {
    let text = Self.open.replacingOccurrences(of: "\"open\"", with: state)
    #expect(throws: DecodingError.self) { try decode(text) }
  }

  @Test(arguments: ["stops_confirmed_at", "alarm_symbol", "unrealized_cents"])
  func refusesAMissingKey(_ key: String) {
    let text = Self.open.replacingOccurrences(of: "\"\(key)\"", with: "\"x_\(key)\"")
    #expect(throws: DecodingError.self) { try decode(text) }
  }

  @Test func refusesAPriceThatIsNotADecimal() {
    let text = Self.open.replacingOccurrences(of: "\"12.48\"", with: "\"12,48\"")
    #expect(throws: DecodingError.self) { try decode(text) }
  }

  @Test func pauseReasonReadsTheBlockCauseOrOtherReason() throws {
    let paused = { (code: String) in
      try self.decode(Self.open.replacingOccurrences(of: "\"reason_code\": null", with: "\"reason_code\": \"\(code)\""))
    }
    #expect(try paused("entry_stop").pauseReason == String(localized: BlockCode.entryStop.title))
    #expect(try paused("stop_held").pauseReason == String(localized: FenceKind.stopHeld.title))
    #expect(try paused("a_newer_cause").pauseReason == String(localized: L10n.reasonOther))
    #expect(try decode(Self.open).pauseReason == nil)
  }

  @Test func progressStaysOnTheBar() {
    let below = ActivityPosition(symbol: "A", last: 9, stop: 10, target: 12, unrealizedCents: nil)
    let above = ActivityPosition(symbol: "A", last: 13, stop: 10, target: 12, unrealizedCents: nil)
    let inverted = ActivityPosition(symbol: "A", last: 11, stop: 12, target: 10, unrealizedCents: nil)
    #expect(below.progress == 0 && above.progress == 1 && inverted.progress == nil)
  }

  @Test func textSlotSplitsAtTheMarker() {
    let slot = TextSlot("Stops confirmed at broker \(TextSlot.marker) ago")
    #expect(slot.before == "Stops confirmed at broker " && slot.after == " ago")
    let spanish = TextSlot("Stops confirmados en el bróker hace \(TextSlot.marker)")
    #expect(spanish.before == "Stops confirmados en el bróker hace " && spanish.after == "")
    #expect(TextSlot("no marker") == TextSlot("no marker"))
    #expect(TextSlot("no marker").after == "")
  }
}
