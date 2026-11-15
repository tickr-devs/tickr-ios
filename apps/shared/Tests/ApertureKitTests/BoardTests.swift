@testable import ApertureKit
import Foundation
import Testing

@Suite struct BoardTests {
  func status(_ name: String) throws -> StatusV1 {
    try #require(Wire.decoder().decode(StatusResponseV1.self, from: fixture(name)).status)
  }

  @Test func dayStatsFromFixture() throws {
    let stats = Board.dayStats(try status("status-response-v1.json"))
    #expect(stats.trades == 1)
    #expect(stats.wins == 0)
    #expect(stats.losses == 1)
    #expect(stats.resultGrossUsd == Decimal(string: "-1.60"))
    #expect(stats.winShare == 0)
  }

  @Test func positionsIsAList() throws {
    #expect(Board.positions(try status("status-response-v1.json")).map(\.symbol) == ["ABCD"])
    #expect(Board.positions(try status("status-response-v1.minimal.json")).isEmpty)
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
    let headline = Headline.make(response: response, fetchError: nil)
    #expect(headline.severity == .alarm)
    #expect(headline.text.contains("EFGH"))
  }

  @Test func eventsCoverEverythingNewestFirst() throws {
    let events = Board.events(try status("status-response-v1.json"))
    #expect(Set(events.map(\.tag)) == ["ENTER", "STOP", "OPEN", "STOP \u{2713}", "FENCE", "DONE"])
    #expect(Set(events.map(\.id)).count == events.count, "ids must be unique")
    #expect(events.first { $0.tag == "STOP" }?.text == "WXYZ @ 5.02 -1.60")
    #expect(events.first { $0.tag == "DONE" }?.text == "Pause entries")
    for pair in zip(events, events.dropFirst()) { #expect(pair.0.time >= pair.1.time) }
  }

  @Test func knownExitReasonsGetTitlesUnknownStayRaw() {
    #expect(Board.exitReasonTitle("stopped-out") == "stopped out")
    #expect(Board.exitReasonTitle("something-new") == "something-new")
  }
}
