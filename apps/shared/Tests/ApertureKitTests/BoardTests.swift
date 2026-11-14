@testable import ApertureKit
import XCTest

final class BoardTests: XCTestCase {
  func status(_ name: String) throws -> StatusV1 {
    try XCTUnwrap(Wire.decoder().decode(StatusResponseV1.self, from: fixture(name)).status)
  }

  func testDayStatsFromFixture() throws {
    let stats = Board.dayStats(try status("status-response-v1.json"))
    XCTAssertEqual(stats.trades, 1)
    XCTAssertEqual(stats.wins, 0)
    XCTAssertEqual(stats.losses, 1)
    XCTAssertEqual(stats.resultGrossUsd, Decimal(string: "-1.60"))
    XCTAssertEqual(stats.winShare, 0)
  }

  func testPositionsIsAList() throws {
    XCTAssertEqual(Board.positions(try status("status-response-v1.json")).map(\.symbol), ["ABCD"])
    XCTAssertEqual(Board.positions(try status("status-response-v1.minimal.json")).count, 0)
  }

  func testEventsCoverEverythingNewestFirst() throws {
    let events = Board.events(try status("status-response-v1.json"))
    XCTAssertEqual(Set(events.map(\.tag)), ["ENTER", "STOP", "OPEN", "STOP \u{2713}", "FENCE", "DONE"])
    XCTAssertEqual(Set(events.map(\.id)).count, events.count, "ids must be unique")
    XCTAssertEqual(events.first { $0.tag == "STOP" }?.text, "WXYZ @ 5.02 -1.60")
    XCTAssertEqual(events.first { $0.tag == "DONE" }?.text, "Pause entries")
    for pair in zip(events, events.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.0.time, pair.1.time) }
  }
}
