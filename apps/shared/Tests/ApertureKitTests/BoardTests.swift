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
