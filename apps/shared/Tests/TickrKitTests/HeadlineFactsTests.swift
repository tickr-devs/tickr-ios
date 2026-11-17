import Foundation
import Testing
@testable import TickrKit

/// The facts beside the headline (mockup v108): the session countdown and the gate badge.
@Suite struct HeadlineFactsTests {
  /// A regular session from 09:30 to 16:00 New York (14:30 to 21:00 UTC), as /jobs sends it.
  static let sessionJSON = """
    {"day": "2026-11-16", "regular_open": "2026-11-16T14:30:00.000Z",
     "last_entry_at": "2026-11-16T20:45:00.000Z", "flatten_at": "2026-11-16T20:55:00.000Z",
     "regular_close": "2026-11-16T21:00:00.000Z", "premarket_open": "2026-11-16T09:00:00.000Z",
     "extended_close": "2026-11-17T01:00:00.000Z"}
    """

  func session() throws -> SessionTimesV1 {
    try Wire.decoder().decode(SessionTimesV1.self, from: Data(Self.sessionJSON.utf8))
  }

  func at(_ text: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: text))
  }

  @Test("Before the open it counts to the open, in hours and minutes")
  func opensInHoursAndMinutes() throws {
    let countdown = try #require(SessionCountdown.make(session: try session(), now: try at("2026-11-16T05:05:00Z")))
    #expect(countdown == SessionCountdown(kind: .opens, minutes: 565))
    #expect(countdown.label == "Opens in")
    #expect(countdown.value == "9 h 25 m")
  }

  @Test("Inside the session it counts to the close; under an hour in minutes only")
  func closesInMinutes() throws {
    let countdown = try #require(SessionCountdown.make(session: try session(), now: try at("2026-11-16T20:18:00Z")))
    #expect(countdown == SessionCountdown(kind: .closes, minutes: 42))
    #expect(countdown.label == "Closes in")
    #expect(countdown.value == "42 m")
  }

  @Test("Part of a minute counts as a whole one, so it never shows 0 m before the moment")
  func roundsUp() throws {
    let countdown = SessionCountdown.make(session: try session(), now: try at("2026-11-16T14:29:30Z"))
    #expect(countdown == SessionCountdown(kind: .opens, minutes: 1))
    #expect(SessionCountdown(kind: .closes, minutes: 60).value == "1 h 0 m")
  }

  @Test("At the open it turns to the close; after the close and without a session it is not shown")
  func boundaries() throws {
    #expect(SessionCountdown.make(session: try session(), now: try at("2026-11-16T14:30:00Z"))
      == SessionCountdown(kind: .closes, minutes: 390))
    #expect(SessionCountdown.make(session: try session(), now: try at("2026-11-16T21:00:00Z")) == nil)
    #expect(SessionCountdown.make(session: nil, now: try at("2026-11-16T15:00:00Z")) == nil)
  }

  /// `swift test` reads the English defaults only; the Russian texts are read from the catalog
  /// and filled in as the app fills them.
  @Test("Russian: «Откроется через 9 ч 25 м», «Закроется через 42 м»")
  func russian() throws {
    let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appending(path: "Sources/TickrKit/Resources/Localizable.xcstrings")
    let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let strings = try #require(catalog["strings"] as? [String: [String: Any]])
    func russian(_ key: String) throws -> String {
      let localizations = try #require(strings[key]?["localizations"] as? [String: [String: [String: String]]])
      return try #require(localizations["ru"]?["stringUnit"]?["value"])
    }
    func filled(_ format: String, _ values: Int...) -> String {
      values.reduce(format) { text, value in
        guard let range = text.range(of: "%lld") else { return text }
        return text.replacingCharacters(in: range, with: String(value))
      }
    }
    #expect(try russian("kit.countdown.opensIn") + " " + filled(try russian("kit.countdown.hoursMinutes"), 9, 25)
      == "Откроется через 9 ч 25 м")
    #expect(try russian("kit.countdown.closesIn") + " " + filled(try russian("kit.countdown.minutes"), 42)
      == "Закроется через 42 м")
    #expect(try russian("kit.gate.open") == "Шлюз открыт")
    #expect(try russian("kit.gate.paused") == "Входы на паузе")
  }

  // MARK: gate

  func status(_ edit: (String) -> String = { $0 }) throws -> StatusResponseV1 {
    let text = try #require(String(data: try fixture("status-response-v1.json"), encoding: .utf8))
    return try Wire.decoder().decode(StatusResponseV1.self, from: Data(edit(text).utf8))
  }

  @Test("The gate badge follows the bot: open, entries paused, or the gate closed")
  func gate() throws {
    let open = try status()
    #expect(EntryGate.make(open.status, headline: Headline.make(response: open, readFailed: false)) == .open)
    let paused = try status { $0.replacingOccurrences(of: "\"entry_stop\": false", with: "\"entry_stop\": true") }
    #expect(EntryGate.make(paused.status, headline: Headline.make(response: paused, readFailed: false)) == .paused)
    let closed = try status { $0.replacingOccurrences(of: "\"open\": true", with: "\"open\": false") }
    #expect(closed.status?.tradingGate.open == false)
    #expect(EntryGate.make(closed.status, headline: Headline.make(response: closed, readFailed: false)) == .closed)
    #expect(EntryGate.open.title.key == "kit.gate.open")
    #expect(String(localized: EntryGate.paused.title) == "Entries paused")
  }

  @Test("An alarm headline hides the gate badge; without a status there is none")
  func alarmHidesGate() throws {
    let response = try status()
    #expect(EntryGate.make(response.status, headline: Headline(text: "", severity: .alarm)) == nil)
    #expect(EntryGate.make(nil, headline: Headline(text: "", severity: .ok)) == nil)
  }
}
