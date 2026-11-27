import Foundation
import Testing
import TickrDesign
@testable import TickrKit
@testable import TickrScreens

@Suite("One send per decision, as the app shows it")
struct EntrySentTests {
  /// An entry record with `sends` (nil = not recorded) and `latest` as both outcomes.
  private func entry(sends: Int?, outcome latest: String = "acknowledged") throws -> EntrySend {
    let outcome = sends == nil ? "null" : "\"\(latest)\""
    let json = """
      {"client_order_id": "ap-0001-e", "intent_at": null, "sent_at": null, "send_outcome": \(outcome),
       "latest_outcome": \(outcome), "sends": \(sends.map(String.init) ?? "null"), "filled_at": null}
      """
    return try Wire.decoder().decode(EntrySend.self, from: Data(json.utf8))
  }

  @Test("Sent once reads quietly with its outcome; twice is an alarm")
  func line() throws {
    let once = EntrySent.line(try entry(sends: 1), cause: nil)
    #expect(once.text == String(localized: L10n.EntrySent.withOutcome(String(localized: L10n.EntrySent.once),
      String(localized: L10n.EntrySent.acknowledged))))
    #expect(once.color != Palette.lossText)
    #expect(once.help == nil)
    #expect(EntrySent.line(try entry(sends: 2), cause: nil).color == Palette.lossText)
    let missing = EntrySent.line(try entry(sends: nil), cause: "journal unreadable")
    #expect(missing.text == String(localized: L10n.EntrySent.notRecorded))
    #expect(missing.help == "journal unreadable")
  }

  @Test("Sent once but not yet answered by the broker is a warning, on the line and the safety row")
  func awaiting() throws {
    for outcome in ["unknown", "attempted", "intent"] {
      let waiting = try entry(sends: 1, outcome: outcome)
      #expect(EntrySent.line(waiting, cause: nil).color == Palette.warningText)
      let entries = [(symbol: "ABCD", entry: waiting), (symbol: "EFGH", entry: try entry(sends: 1))]
      #expect(EntrySent.summary(entries)?.text == String(localized: L10n.EntrySent.awaiting(1)))
      #expect(EntrySent.summary(entries)?.tone == .warning)
    }
  }

  @Test("The safety row names the first entry sent other than once, before missing records")
  func summary() throws {
    let entries = [(symbol: "ABCD", entry: try entry(sends: nil)), (symbol: "WXYZ", entry: try entry(sends: 2)),
      (symbol: "EFGH", entry: try entry(sends: 1))]
    #expect(EntrySent.summary(entries)?.text == String(localized: L10n.EntrySent.breach("WXYZ", 2)))
    #expect(EntrySent.summary(Array(entries.prefix(1)))?.text == String(localized: L10n.EntrySent.unrecorded(1)))
    #expect(EntrySent.summary(Array(entries.suffix(1)))?.text == String(localized: L10n.EntrySent.allOnce(1)))
    #expect(EntrySent.summary([]) == nil)
  }

  @Test("Today's fixture entries are all sent once")
  func fixtureEntries() throws {
    let status = try fixture(StatusV1.self, "status-v1.example.json")
    let entries = Board.positions(status).map { (symbol: $0.symbol, entry: $0.entry) }
      + status.tradesToday.map { (symbol: $0.symbol, entry: $0.entry) }
    #expect(EntrySent.summary(entries)?.tone == .profit)
  }
}
