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

  func next(_ day: String, open: String, close: String) throws -> NextSessionV1 {
    let json = """
      {"day": "\(day)", "regular_open": "\(open)", "regular_close": "\(close)", "kind": "regular"}
      """
    return try Wire.decoder().decode(NextSessionV1.self, from: Data(json.utf8))
  }

  /// Today's session from /jobs as next_session names it before its open.
  func todayNext() throws -> NextSessionV1 {
    try next("2026-11-16", open: "2026-11-16T14:30:00.000Z", close: "2026-11-16T21:00:00.000Z")
  }

  @Test("Before the open it counts to the open, in hours and minutes")
  func opensInHoursAndMinutes() throws {
    let countdown = try #require(
      SessionCountdown.make(session: try session(), next: try todayNext(), now: try at("2026-11-16T05:05:00Z")))
    #expect((countdown.kind, countdown.minutes) == (.opens, 565))
    #expect(countdown.label == "Opens in")
    #expect(countdown.value() == "9 h 25 m")
  }

  @Test("Inside the session it counts to the close; under an hour in minutes only")
  func closesInMinutes() throws {
    let tomorrow = try next("2026-11-17", open: "2026-11-17T14:30:00.000Z", close: "2026-11-17T21:00:00.000Z")
    let countdown = try #require(
      SessionCountdown.make(session: try session(), next: tomorrow, now: try at("2026-11-16T20:18:00Z")))
    #expect((countdown.kind, countdown.minutes) == (.closes, 42))
    #expect(countdown.label == "Closes in")
    #expect(countdown.value() == "42 m")
  }

  @Test("Part of a minute counts as a whole one, so it never shows 0 m before the moment")
  func roundsUp() throws {
    let countdown = SessionCountdown.make(session: try session(), next: try todayNext(),
      now: try at("2026-11-16T14:29:30Z"))
    #expect(countdown?.minutes == 1)
    #expect(SessionCountdown(kind: .closes, minutes: 60, at: Date()).value() == "1 h 0 m")
  }

  @Test("After the close it counts to the next session's open, overnight too")
  func afterTheClose() throws {
    let tomorrow = try next("2026-11-17", open: "2026-11-17T14:30:00.000Z", close: "2026-11-17T21:00:00.000Z")
    // 23:05 New York: 10 h 25 m to Tuesday's 09:30.
    let countdown = try #require(
      SessionCountdown.make(session: try session(), next: tomorrow, now: try at("2026-11-17T04:05:00Z")))
    #expect((countdown.kind, countdown.minutes) == (.opens, 625))
    #expect(countdown.value() == "10 h 25 m")
  }

  @Test("A day or more away (Friday evening to Monday) it names the weekday and time")
  func weekend() throws {
    let monday = try next("2026-11-23", open: "2026-11-23T14:30:00.000Z", close: "2026-11-23T21:00:00.000Z")
    let countdown = try #require(SessionCountdown.make(session: nil, next: monday, now: try at("2026-11-20T22:00:00Z")))
    #expect(countdown.kind == .opensOn)
    #expect(countdown.label == "Opens")
    #expect(countdown.value(locale: Locale(identifier: "en_US")) == "Mon 09:30")
    // Spanish: the language's own weekday abbreviation ("lun" or "lun."), then the time.
    let spanish = countdown.value(locale: Locale(identifier: "es_US"))
    #expect(spanish.lowercased().hasPrefix("lun") && spanish.hasSuffix(" 09:30"), "\(spanish)")
    // 23 h 59 m is still a countdown.
    let almost = SessionCountdown.make(session: nil, next: monday, now: try at("2026-11-22T14:31:00Z"))
    #expect(almost?.kind == .opens)
  }

  @Test("At the open it turns to the close; nothing is shown when neither answers")
  func boundaries() throws {
    let countdown = SessionCountdown.make(session: try session(), next: try todayNext(), now: try at("2026-11-16T14:30:00Z"))
    #expect((countdown?.kind, countdown?.minutes) == (.closes, 390))
    // After the close without a next session (the calendar could not answer), or no data at all.
    #expect(SessionCountdown.make(session: try session(), next: nil, now: try at("2026-11-16T21:00:00Z")) == nil)
    #expect(SessionCountdown.make(session: nil, next: nil, now: try at("2026-11-16T15:00:00Z")) == nil)
    // An older bot without next_session: today's open while it is ahead.
    #expect(SessionCountdown.make(session: try session(), next: nil, now: try at("2026-11-16T14:00:00Z"))?.kind == .opens)
  }

  /// `swift test` reads the English defaults only; the Spanish texts are read from the catalog
  /// and filled in as the app fills them.
  @Test("Spanish: «Abre en 9 h 25 m», «Cierra en 42 m»")
  func spanish() throws {
    let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appending(path: "Sources/TickrKit/Resources/Localizable.xcstrings")
    let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let strings = try #require(catalog["strings"] as? [String: [String: Any]])
    func spanish(_ key: String) throws -> String {
      let localizations = try #require(strings[key]?["localizations"] as? [String: [String: [String: String]]])
      return try #require(localizations["es"]?["stringUnit"]?["value"])
    }
    func filled(_ format: String, _ values: Int...) -> String {
      values.reduce(format) { text, value in
        guard let range = text.range(of: "%lld") else { return text }
        return text.replacingCharacters(in: range, with: String(value))
      }
    }
    #expect(try spanish("kit.countdown.opensIn") + " " + filled(try spanish("kit.countdown.hoursMinutes"), 9, 25)
      == "Abre en 9 h 25 m")
    #expect(try spanish("kit.countdown.closesIn") + " " + filled(try spanish("kit.countdown.minutes"), 42)
      == "Cierra en 42 m")
    #expect(try spanish("kit.countdown.opensOn") == "Abre")
    // Beside a closed gate's badge, as the English "Holding 2 positions · stops verified".
    #expect(filled(try spanish("kit.headline.holding"), 2) + " · " + (try spanish("kit.headline.stopsVerified"))
      == "Posiciones: 2 · stops verificados")
    #expect(String(localized: L10n.headlineHolding(2)) + " · " + String(localized: L10n.headlineStopsVerified)
      == "Holding 2 positions · stops verified")
    #expect(try spanish("kit.entryGate.open") == "Puerta abierta")
    #expect(try spanish("kit.entryGate.paused") == "Entradas en pausa")
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
    #expect(EntryGate.open.title.key == "kit.entryGate.open")
    #expect(String(localized: EntryGate.paused.title) == "Entries paused")
  }

  /// The fixture with the trading gate closed in config: the bot's block and gate say so.
  func gateClosed(flat: Bool) throws -> StatusResponseV1 {
    try status {
      var text = $0.replacingOccurrences(of: "\"open\": true", with: "\"open\": false")
        .replacingOccurrences(of: "\"cause\": \"own_trade_open\"", with: "\"cause\": \"trading_gate_closed\"")
        .replacingOccurrences(of: "\"attention\": false", with: "\"attention\": true")
      if flat {
        let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        if var object, var inner = object["status"] as? [String: Any] {
          inner["positions"] = []
          inner["position"] = NSNull()
          object["status"] = inner
          if let data = try? JSONSerialization.data(withJSONObject: object),
            let flatText = String(bytes: data, encoding: .utf8) {
            text = flatText
          }
        }
      }
      return text
    }
  }

  @Test("Gate closed in config and flat: a calm \"Entries off\" with the grey gate badge (mockup v109)")
  func gateClosedFlat() throws {
    let response = try gateClosed(flat: true)
    #expect(response.status?.positions.isEmpty == true)
    let headline = Headline.make(response: response, readFailed: false)
    #expect(headline == Headline(text: "Entries off", severity: .ok, detail: "trading gate closed in config"))
    #expect(EntryGate.make(response.status, headline: headline) == .closed)
  }

  @Test("Gate closed in config with a position open: holding wins, the grey gate badge beside it")
  func gateClosedHolding() throws {
    let response = try gateClosed(flat: false)
    #expect(response.status?.positions.isEmpty == false)
    let headline = Headline.make(response: response, readFailed: false)
    #expect(headline.text == "Holding 1 position")
    #expect(headline.detail == "stop verified")
    #expect(headline.severity == .ok)
    #expect(EntryGate.make(response.status, headline: headline) == .closed)
  }

  @Test("An alarm headline hides the gate badge; without a status there is none")
  func alarmHidesGate() throws {
    let response = try status()
    #expect(EntryGate.make(response.status, headline: Headline(text: "", severity: .alarm)) == nil)
    #expect(EntryGate.make(nil, headline: Headline(text: "", severity: .ok)) == nil)
  }
}
