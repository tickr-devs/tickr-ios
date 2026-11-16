import Foundation
import Testing
import TickrKit

/// The session strip's day on both apps comes from the bot's `/jobs` session.
@Suite struct SessionSpanTests {
  /// The jobs fixture's session (Mon Nov 16: pre-market 04:00, open 09:30, last entry 15:45,
  /// flatten 15:55, close 16:00, extended close 20:00 New York).
  private func session(dropping keys: [String] = []) throws -> SessionTimesV1 {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("jobs-v1.json")) as? [String: Any])
    var times = try #require(object["session"] as? [String: Any])
    for key in keys { times[key] = nil }
    object["session"] = times
    let jobs = try Wire.decoder().decode(JobsV1.self, from: JSONSerialization.data(withJSONObject: object))
    return try #require(jobs.session)
  }

  private func at(_ time: String) throws -> Date { try WireTime(time).date }

  @Test func spanIsTheCalendarsExtendedHours() throws {
    let span = SessionSpan(try session())
    #expect(span.extendedHoursKnown)
    #expect(span.start == (try at("2026-11-16T09:00:00.000Z")))
    #expect(span.end == (try at("2026-11-17T01:00:00.000Z")))
    #expect(span.share(span.start) == 0)
    #expect(span.share(span.end) == 1)
    #expect(span.share(span.regularOpen) == (try at("2026-11-16T14:30:00.000Z")).timeIntervalSince(span.start)
      / span.end.timeIntervalSince(span.start))
  }

  @Test func aHalfDaysEarlierCloseMovesTheEnd() throws {
    var object = try #require(try JSONSerialization.jsonObject(with: fixture("jobs-v1.json")) as? [String: Any])
    var times = try #require(object["session"] as? [String: Any])
    times["regular_close"] = "2026-11-16T18:00:00.000Z"
    times["extended_close"] = "2026-11-16T22:00:00.000Z"
    object["session"] = times
    let jobs = try Wire.decoder().decode(JobsV1.self, from: JSONSerialization.data(withJSONObject: object))
    let span = SessionSpan(try #require(jobs.session))
    #expect(span.end == (try at("2026-11-16T22:00:00.000Z")))
    #expect(span.part(at: try at("2026-11-16T19:00:00.000Z")) == .afterHours)
  }

  @Test func anOlderBotsSessionTakesTheUsualExtendedHours() throws {
    let span = SessionSpan(try session(dropping: ["premarket_open", "extended_close"]))
    #expect(!span.extendedHoursKnown)
    #expect(span.start == (try at("2026-11-16T09:00:00.000Z")))
    #expect(span.end == (try at("2026-11-17T01:00:00.000Z")))
  }

  @Test func partsOfTheDay() throws {
    let span = SessionSpan(try session())
    #expect(span.part(at: try at("2026-11-16T08:59:59.000Z")) == .closed)
    #expect(span.part(at: try at("2026-11-16T09:00:00.000Z")) == .preMarket)
    #expect(span.part(at: try at("2026-11-16T14:30:00.000Z")) == .regular)
    #expect(span.part(at: try at("2026-11-16T21:00:00.000Z")) == .afterHours)
    #expect(span.part(at: try at("2026-11-17T01:00:00.000Z")) == .closed)
    #expect(!span.contains(span.start) && span.contains(span.regularOpen) && !span.contains(span.end))
  }

  @Test("The marks passed change only when now passes a mark")
  func marksPassed() throws {
    let span = SessionSpan(try session())
    let passed = { (time: String) in span.marksPassed(at: try self.at(time)) }
    #expect(try passed("2026-11-16T08:00:00.000Z") == 0)
    #expect(try passed("2026-11-16T09:00:00.000Z") == 1)  // 04:00, pre-market
    #expect(try passed("2026-11-16T14:29:59.000Z") == 1)
    #expect(try passed("2026-11-16T14:30:00.000Z") == 2)  // open
    #expect(try passed("2026-11-16T18:00:00.000Z") == 2)  // the same all through midday
    #expect(try passed("2026-11-16T20:45:00.000Z") == 3)  // last entry
    #expect(try passed("2026-11-16T20:55:00.000Z") == 4)  // flatten
    #expect(try passed("2026-11-16T21:00:00.000Z") == 5)  // close
    #expect(try passed("2026-11-17T01:00:00.000Z") == 6)  // extended close
  }

  @Test("A now line moves to whole minutes only")
  func minute() throws {
    let start = try at("2026-11-16T15:00:00.000Z")
    #expect(SessionSpan.minute(try at("2026-11-16T15:00:59.900Z")) == start)
    #expect(SessionSpan.minute(start) == start)
    #expect(SessionSpan.minute(try at("2026-11-16T15:01:00.000Z")) == start.addingTimeInterval(60))
  }
}
