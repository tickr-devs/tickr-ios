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
    #expect(stats.resultUsd == Decimal(string: "-1.67"))  // the bot's own net, not the broker's -1.64
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

  /// The bot's block is then the unprotected fence itself: the headline says the missing stop
  /// once, not again as "A position has no verified stop" (simulator check, 2026-11-26).
  @Test("A missing stop that is also the entry block is said once")
  func missingStopSaidOnce() throws {
    var response = try #require(try JSONSerialization.jsonObject(with: fixture("status-response-v1.json")) as? [String: Any])
    var status = try #require(response["status"] as? [String: Any])
    var positions = try #require(status["positions"] as? [[String: Any]])
    var stop = try #require(positions[0]["stop"] as? [String: Any])
    stop["state"] = "pending"
    positions[0]["stop"] = stop
    status["positions"] = positions
    var block = try #require(status["entry_block"] as? [String: Any])
    block["cause"] = FenceKind.unprotected.rawValue
    block["attention"] = true
    status["entry_block"] = block
    response["status"] = status
    let decoded = try Wire.decoder().decode(StatusResponseV1.self, from: JSONSerialization.data(withJSONObject: response))
    let headline = Headline.make(response: decoded, readFailed: false)
    #expect(headline.severity == .alarm)
    #expect(!headline.text.contains(String(localized: L10n.fenceUnprotected)))
    #expect(!headline.text.hasSuffix(" "))
  }

  @Test func eventsCoverEverythingNewestFirst() throws {
    let events = Board.events(try status("status-response-v1.json"))
    // The fixture's trade closed with the replay word "stop": the shared map reads it as stopped out.
    #expect(Set(events.map(\.tag)) == ["ENTER", "STOPPED OUT", "OPEN", "STOP \u{2713}", "FENCE", "DONE"])
    #expect(Set(events.map(\.id)).count == events.count, "ids must be unique")
    #expect(events.first { $0.tag == "STOPPED OUT" }?.text == "WXYZ @ 5.02 -1.67")  // the exact result once listed
    #expect(events.first { $0.tag == "DONE" }?.text == "Pause entries")
    for pair in zip(events, events.dropFirst()) { #expect(pair.0.time >= pair.1.time) }
  }

  /// The bot lists its latest commands whatever their day: one from an earlier New York day is
  /// not today's event (a "Stop bot" of last night beside a running bot reads as an alarm).
  @Test func commandsOfAnEarlierDayAreLeftOut() throws {
    let today = "\"processed_at\": \"2026-11-16T15:00:00.123Z\""
    let yesterday = "\"processed_at\": \"2026-11-16T02:00:00.123Z\""
    let text = try #require(String(data: fixture("status-response-v1.json"), encoding: .utf8))
    #expect(text.contains(today))
    let shifted = try #require(Wire.decoder().decode(StatusResponseV1.self,
      from: Data(text.replacingOccurrences(of: today, with: yesterday).utf8)).status)
    #expect(Board.events(shifted).allSatisfy { !$0.id.hasPrefix(Board.commandID) })
    #expect(Board.events(try status("status-response-v1.json")).contains { $0.id.hasPrefix(Board.commandID) })
  }

  @Test func aRefusedCommandIsAmberNotDanger() {
    #expect(Board.commandTone(.refused) == .amber)
    #expect(Board.commandTone(.done) == .blue)
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
    #expect(Board.exitReasonTitle("order-resolved-by-operator") == "resolved by the operator")
    #expect(Board.exitKind("order-resolved-by-operator") == .forced)
  }

  /// A replay's trade (a what-if) carries the replay's words: the same map reads
  /// them, never as the raw value ("STRATEGY_EXIT").
  @Test func replayExitReasonsReadAsTheBotsOwn() {
    #expect(Board.exitReasonTitle("stop") == Board.exitReasonTitle("stopped-out"))
    #expect(Board.exitReasonTitle("strategy_exit") == Board.exitReasonTitle("strategy-exit"))
    #expect(Board.exitReasonTitle("flatten") == Board.exitReasonTitle("session-flatten"))
    #expect(Board.exitReasonTitle("end_of_data") == "bars ran out")
    #expect(Board.exitLook("stop") == .stoppedOut)
    #expect(Board.exitLook("strategy_exit") == .strategy)
    #expect(Board.exitLook("flatten") == .other)
    #expect(Board.exitLook("end_of_data") == .other)
    #expect(Board.exitKind("flatten") == .forced)
  }
}
