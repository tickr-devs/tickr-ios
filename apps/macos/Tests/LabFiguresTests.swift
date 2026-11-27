import Foundation
import Testing
@testable import TickrKit
@testable import TickrScreens

/// The Lab's figures from the replay: the active version's test on past days and which compared
/// version earned more.
@Suite("Lab figures")
struct LabFiguresTests {
  /// The replay fixture (the active version against an observer over 20 sessions, both done) with
  /// `changes` applied to its top-level keys.
  static func replay(_ changes: [String: Any] = [:]) throws -> LabReplayV1 {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("lab-replay-v1.json"))
    var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    for (key, value) in changes { object[key] = value }
    return try Wire.decoder().decode(LabReplayV1.self, from: JSONSerialization.data(withJSONObject: object))
  }

  /// The fixture's second version with its net with the bot's limits set to `usd`.
  static func compare(netUSD usd: String) throws -> [String: Any] {
    let data = try Data(contentsOf: fixturesDir.appendingPathComponent("lab-replay-v1.json"))
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    var leg = try #require(object["compare"] as? [String: Any])
    var summary = try #require(leg["summary"] as? [String: Any])
    summary["bot_total_usd"] = usd
    leg["summary"] = summary
    return leg
  }

  @Test("A finished run of the active version over the last sessions is its test")
  func activeTest() throws {
    let test = try #require(LabFigures.activeTest(try Self.replay()))
    #expect(test.botTotalUsd.value == Decimal(string: "412.50"))
    #expect(test.sessions == 20)
  }

  @Test("No test from a run of another version, of one day, still running or none")
  func noActiveTest() throws {
    #expect(LabFigures.activeTest(nil) == nil)
    #expect(LabFigures.activeTest(try Self.replay(["folder": "volume-shock-v1"])) == nil)
    #expect(LabFigures.activeTest(try Self.replay(["day": "2026-11-13"])) == nil)
    #expect(LabFigures.activeTest(try Self.replay(["state": "running"])) == nil)
    #expect(LabFigures.activeTest(try Self.replay(["versions": []])) == nil)
  }

  @Test("The second version's net with the bot's limits against the first's")
  func verdict() throws {
    #expect(LabFigures.verdict(try Self.replay()) == .more(Decimal(string: "75.50")!))
    #expect(LabFigures.verdict(try Self.replay(["compare": try Self.compare(netUSD: "400.00")]))
      == .less(Decimal(string: "12.50")!))
    #expect(LabFigures.verdict(try Self.replay(["compare": try Self.compare(netUSD: "412.50")])) == .same)
  }

  @Test("No verdict for one day or without the second version's result")
  func noVerdict() throws {
    #expect(LabFigures.verdict(try Self.replay(["day": "2026-11-13"])) == nil)
    #expect(LabFigures.verdict(try Self.replay(["compare": NSNull()])) == nil)
  }
}
