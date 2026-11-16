import Foundation
import Testing
@testable import TickrKit

@Suite struct BoardTests {
  func status(_ name: String) throws -> StatusV1 {
    try #require(Wire.decoder().decode(StatusResponseV1.self, from: fixture(name)).status)
  }

  @Test func dayStatsFromFixture() throws {
    let stats = Board.dayStats(try status("status-response-v1.json"))
    #expect(stats.trades == 1)
    #expect(stats.wins == 0)
    #expect(stats.losses == 1)
    #expect(stats.resultUsd == Decimal(string: "-1.64"))  // the fixture's broker result
    #expect(stats.winShare == 0)
  }

  @Test func positionsIsAList() throws {
    #expect(Board.positions(try status("status-response-v1.json")).map(\.symbol) == ["ABCD"])
    #expect(Board.positions(try status("status-response-v1.minimal.json")).isEmpty)
  }

  @Test("The event line shows the latest of the status's events and the risk refusals")
  func latestEventIncludesRefusals() throws {
    let status = try status("status-response-v1.json")
    #expect(Board.latestEvent(status, skipped: nil) == Board.events(status).first)
    // ZNTH was refused at 15:35, after everything the status lists (15:00); WXYZ, later still,
    // was not evaluated, so it is no refusal.
    let skipped = try Wire.decoder().decode(SkippedV1.self, from: fixture("skipped-v1.json"))
    let latest = try #require(Board.latestEvent(status, skipped: skipped))
    #expect(latest.tag == String(localized: L10n.tagRefused))
    let znth = try #require(skipped.signals.first { $0.symbol == "ZNTH" })
    #expect(latest.text == "ZNTH" + Board.refusalGap + (FlowBoard.note(znth) ?? ""))
    #expect(latest.tone == .amber)
  }

  @Test("A fence keyed by a position's or today's trade's order names that symbol first")
  func fenceSymbol() throws {
    let status = try status("status-response-v1.json")
    func fence(_ kind: String) throws -> Fence {
      let json = #"{"kind":"\#(kind)","since":"2026-11-16T15:00:00.123Z","text":"t","code":"x","params":{}}"#
      return try Wire.decoder().decode(Fence.self, from: Data(json.utf8))
    }
    #expect(Board.fenceSymbol(try fence("unprotected-timeout:0001"), status: status) == "ABCD")
    #expect(Board.fenceSymbol(try fence("status-unknown:ap-0001-s"), status: status) == "ABCD")
    #expect(Board.fenceSymbol(try fence("unprotected:0999"), status: status) == nil)
    #expect(Board.fenceSymbol(try fence("startup-reconcile"), status: status) == nil)
    #expect(Board.fenceText(try fence("unprotected-timeout:0001"), status: status)
      .hasPrefix("ABCD" + ApiText.keySeparator))
    #expect(!Board.fenceTitle(try fence("unprotected-timeout:0001"), status: status).contains("0001"))
    // A closed trade of the day still names the fence after its position is gone.
    #expect(Board.fenceSymbol(try fence("unprotected-timeout:0002"), status: status) == "WXYZ")
  }

  /// The fixture's status with a second open position, EFGH, whose stop is still pending.
  func twoPositions() throws -> StatusResponseV1 {
    var response = try #require(try JSONSerialization.jsonObject(with: fixture("status-response-v1.json")) as? [String: Any])
    var status = try #require(response["status"] as? [String: Any])
    var positions = try #require(status["positions"] as? [[String: Any]])
    var second = positions[0]
    var stop = try #require(second["stop"] as? [String: Any])
    stop["state"] = "pending"
    second["stop"] = stop
    second["symbol"] = "EFGH"
    positions.append(second)
    status["positions"] = positions
    response["status"] = status
    return try Wire.decoder().decode(StatusResponseV1.self, from: JSONSerialization.data(withJSONObject: response))
  }

  @Test("Every open position counts: the list, the events and the headline's missing stop")
  func severalPositions() throws {
    let response = try twoPositions()
    let status = try #require(response.status)
    #expect(Board.positions(status).map(\.symbol) == ["ABCD", "EFGH"])
    let opened = Board.events(status).filter { $0.tag == "OPEN" }.map(\.text)
    #expect(opened.count == 2)
    #expect(opened.contains { $0.hasPrefix("EFGH") })
    let headline = Headline.make(response: response, readFailed: false)
    #expect(headline.severity == .alarm)
    #expect(headline.text.contains("EFGH"))
  }

  @Test func eventsCoverEverythingNewestFirst() throws {
    let events = Board.events(try status("status-response-v1.json"))
    #expect(Set(events.map(\.tag)) == ["ENTER", "STOP", "OPEN", "STOP \u{2713}", "FENCE", "DONE"])
    #expect(Set(events.map(\.id)).count == events.count, "ids must be unique")
    #expect(events.first { $0.tag == "STOP" }?.text == "WXYZ @ 5.02 -1.67")  // the exact result once listed
    #expect(events.first { $0.tag == "DONE" }?.text == "Pause entries")
    for pair in zip(events, events.dropFirst()) { #expect(pair.0.time >= pair.1.time) }
  }

  @Test("A forced close is amber and a protection failure red whatever the result; an ordinary exit by its sign")
  func exitToneFollowsTheReason() {
    let gain = Decimal(string: "12.50")!
    let loss = Decimal(string: "-3.10")!
    for forced in ["session-flatten", "operator-flatten", "operator-interrupt", "stream-lost"] {
      #expect(Board.exitTone(forced, result: gain) == .amber)
      #expect(Board.exitTone(forced, result: loss) == .amber)
    }
    for failure in ["stop-rejected", "unprotected-too-long"] {
      #expect(Board.exitTone(failure, result: gain) == .red)
    }
    #expect(Board.exitTone("something-new", result: gain) == .amber)
    #expect(Board.exitTone("stopped-out", result: loss) == .red)
    #expect(Board.exitTone("strategy-exit", result: gain) == .green)
    #expect(Board.exitTone("hold-elapsed", result: 0) == .muted)
  }

  @Test func knownExitReasonsGetTitlesUnknownStayRaw() {
    #expect(Board.exitReasonTitle("stopped-out") == "stopped out")
    #expect(Board.exitReasonTitle("something-new") == "something-new")
  }

  @Test func everyKnownExitReasonHasItsOwnSymbolUnknownGetsTheQuestionMark() {
    #expect(Board.exitReasonSymbol("stopped-out") == ExitReason.stoppedOutSymbol)
    #expect(Board.exitReasonSymbol("hold-elapsed") == ExitReason.holdSymbol)
    #expect(Board.exitReasonSymbol("something-new") == ExitReason.unknownSymbol)
  }
}
