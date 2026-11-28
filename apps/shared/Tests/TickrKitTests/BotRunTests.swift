import Foundation
import Testing
@testable import TickrKit

@Suite("The bot's run by its schedule (page p-off)")
struct BotRunTests {
  /// The off-schedule fixture made flat, with its staleness and schedule changed as a test needs.
  static func response(
    stale: Bool = true, expectedRunning: Bool = false, flat: Bool = true, schedule: Bool = true, status: Bool = true
  ) throws -> StatusResponseV1 {
    var json = try #require(
      try JSONSerialization.jsonObject(with: fixture("status-response-v1.off-schedule.json")) as? [String: Any])
    let keepStatus = status
    var status = try #require(json["status"] as? [String: Any])
    if flat {
      status["position"] = NSNull()
      status["positions"] = [Any]()
      status["working_entries"] = [Any]()
    }
    json["status"] = keepStatus ? status : NSNull()
    json["stale"] = stale
    if schedule {
      var run = try #require(json["schedule"] as? [String: Any])
      run["expected_running"] = expectedRunning
      json["schedule"] = run
    } else {
      json["schedule"] = NSNull()
    }
    return try Wire.decoder().decode(StatusResponseV1.self, from: JSONSerialization.data(withJSONObject: json))
  }

  /// The fixture's next start, 2026-11-23 04:00 ET (a Monday).
  static let start = Date(timeIntervalSince1970: 1_795_424_400)
  static let staleSeconds: TimeInterval = 120
  static let hour: TimeInterval = 3_600
  static let minute: TimeInterval = 60

  @Test("The fixture's next start is the one these tests count from")
  func startMatches() throws {
    #expect(try Self.response().schedule?.nextStartAt.date == Self.start)
  }

  @Test("Saturday night: off until Monday, calm, said as a weekend")
  func offWeekend() throws {
    let saturday = Self.start.addingTimeInterval(-2 * 24 * Self.hour)
    let run = try #require(BotRun.make(response: Self.response(), staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: saturday))
    guard case let .off(start, _, weekend) = run else { Issue.record("not off: \(run)"); return }
    #expect(start == Self.start)
    #expect(weekend)
    #expect(run.calm)
    let headline = try #require(run.headline(lastAnswer: nil, now: saturday))
    #expect(headline.calm)
    #expect(headline.severity == .ok)
    #expect(run.shortText != nil)
  }

  @Test("A weekday: off, not a weekend")
  func offWeekday() throws {
    let response = try Self.response()
    let end = try #require(response.schedule).nextEndAt.date
    // Friday 16:00 ET and Monday 03:00 ET.
    let friday = Self.start.addingTimeInterval(-3 * 24 * Self.hour + 12 * Self.hour)
    let monday = Self.start.addingTimeInterval(-Self.hour)
    #expect(BotRun.make(response: response, staleSeconds: Self.staleSeconds, runStartedAt: nil, now: friday)
      == .off(start: Self.start, end: end, weekend: false))
    #expect(BotRun.make(response: response, staleSeconds: Self.staleSeconds, runStartedAt: nil, now: monday)
      == .off(start: Self.start, end: end, weekend: false))
  }

  @Test("Less than a quarter of an hour to the start: starts in N min")
  func startingSoon() throws {
    let now = Self.start.addingTimeInterval(-8 * Self.minute)
    let run = try #require(BotRun.make(response: Self.response(), staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: now))
    guard case .startingSoon = run else { Issue.record("not soon: \(run)"); return }
    #expect(run.calm)
    #expect(run.headline(lastAnswer: nil, now: now)?.text.contains("8") == true)
  }

  @Test("Meant to run, inside the stale limit after its start: starting, calm")
  func starting() throws {
    let response = try Self.response(expectedRunning: true)
    let now = Self.start.addingTimeInterval(Self.minute)
    let run = BotRun.make(response: response, staleSeconds: Self.staleSeconds, runStartedAt: Self.start, now: now)
    #expect(run == .starting(start: Self.start))
    #expect(run?.calm == true)
  }

  @Test("Meant to run and silent past the stale limit: not answering, red")
  func silent() throws {
    let response = try Self.response(expectedRunning: true)
    let now = Self.start.addingTimeInterval(Self.staleSeconds + Self.minute)
    let run = try #require(BotRun.make(response: response, staleSeconds: Self.staleSeconds, runStartedAt: Self.start,
      now: now))
    #expect(run == .silent(start: Self.start))
    #expect(!run.calm)
    #expect(run.shortText == nil)
    let headline = try #require(run.headline(lastAnswer: Self.start, now: now))
    #expect(headline.severity == .alarm)
    #expect(!headline.calm)
  }

  @Test("Meant to run without its start: silent, never starting")
  func silentWithoutStart() throws {
    let response = try Self.response(expectedRunning: true)
    let run = BotRun.make(response: response, staleSeconds: Self.staleSeconds, runStartedAt: nil, now: Self.start)
    #expect(run == .silent(start: nil))
  }

  @Test("A fresh status is running, whatever the calendar says")
  func freshRuns() throws {
    let run = BotRun.make(response: try Self.response(stale: false), staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: Self.start.addingTimeInterval(-Self.hour))
    #expect(run == .running)
    #expect(run?.headline(lastAnswer: nil, now: Self.start) == nil)
  }

  @Test("A position or a working entry in the last status: nil, the alarm stays")
  func holdingKeepsAlarm() throws {
    let holding = try Self.response(flat: false)
    #expect(BotRun.make(response: holding, staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: Self.start.addingTimeInterval(-Self.hour)) == nil)
    let working = try Wire.decoder().decode(StatusResponseV1.self, from: fixture("status-response-v1.working-entry.json"))
    #expect(BotRun.make(response: working, staleSeconds: Self.staleSeconds, runStartedAt: nil, now: Self.start) == nil)
  }

  @Test("No schedule: nil, the screens as before")
  func noSchedule() throws {
    #expect(BotRun.make(response: try Self.response(schedule: false), staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: Self.start) == nil)
    #expect(BotRun.make(response: nil, staleSeconds: Self.staleSeconds, runStartedAt: nil, now: Self.start) == nil)
  }

  @Test("No status with a schedule: nil, what the bot holds is unknown")
  func noStatus() throws {
    #expect(BotRun.make(response: try Self.response(status: false), staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: Self.start.addingTimeInterval(-Self.hour)) == nil)
  }

  @Test("The start already past while the schedule still says off: silent, never starting soon")
  func pastStart() throws {
    let run = BotRun.make(response: try Self.response(), staleSeconds: Self.staleSeconds, runStartedAt: nil,
      now: Self.start.addingTimeInterval(Self.minute))
    #expect(run == .silent(start: Self.start))
    #expect(run?.calm == false)
  }
}
