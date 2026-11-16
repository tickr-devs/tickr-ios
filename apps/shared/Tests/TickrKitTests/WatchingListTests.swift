import Foundation
import Testing
@testable import TickrKit

/// A watching-v1 row decoded from JSON, as the API sends it.
private func row(
  _ symbol: String, _ verdict: String, closeness: String?, quoteAge: String? = nil,
  at: String = "2026-11-16T15:00:00.000Z"
) throws -> WatchingRowV1 {
  let json = """
  {"symbol": "\(symbol)", "at": "\(at)", "strategy": {"name": "price-action-v1", "version": "1"},
   "verdict": "\(verdict)", "decisive_check": null,
   "closeness": \(closeness.map { "\"\($0)\"" } ?? "null"),
   "closeness_cause": \(closeness == nil ? "\"no failed check\"" : "null"),
   "quote_age_seconds": \(quoteAge.map { "\"\($0)\"" } ?? "null"),
   "quote_age_cause": \(quoteAge == nil ? "\"not recorded\"" : "null")}
  """
  return try Wire.decoder().decode(WatchingRowV1.self, from: Data(json.utf8))
}

@Suite struct WatchingListTests {
  /// Five WATCH rows in no particular order, one without closeness (the API sends only WATCH).
  private func rows() throws -> [WatchingRowV1] {
    [
      try row("MNOP", "WATCH", closeness: "0.3", quoteAge: "0.4", at: "2026-11-16T15:02:00.000Z"),
      try row("ABCD", "WATCH", closeness: "0.9", quoteAge: "1.2", at: "2026-11-16T15:00:00.000Z"),
      try row("EFGH", "WATCH", closeness: nil, at: "2026-11-16T15:04:00.000Z"),
      try row("QRST", "WATCH", closeness: "0.5", quoteAge: "2.5", at: "2026-11-16T15:01:00.000Z"),
      try row("UVWX", "WATCH", closeness: "0.9", quoteAge: "0.4", at: "2026-11-16T15:02:00.000Z"),
    ]
  }

  @Test func topThreeAreTheClosest() throws {
    #expect(WatchingList.top(try rows()).map(\.symbol) == ["ABCD", "UVWX", "QRST"])
    #expect(WatchingList.top(try rows(), count: 1).map(\.symbol) == ["ABCD"])
    #expect(WatchingList.top(Array(try rows().prefix(2))).count == 2)
    #expect(WatchingList.top([]).isEmpty)
  }

  @Test func showAllOnlyWhenRowsAreHidden() throws {
    #expect(WatchingList.hasMore(try rows()))
    #expect(!WatchingList.hasMore(Array(try rows().prefix(WatchingList.shown))))
  }

  @Test func closestMatchesTheAPIOrder() throws {
    // Closeness high to low, the tie by symbol, unknown closeness last.
    #expect(WatchingList.sorted(try rows(), by: .closest).map(\.symbol) == ["ABCD", "UVWX", "QRST", "MNOP", "EFGH"])
  }

  @Test func symbolOrder() throws {
    #expect(WatchingList.sorted(try rows(), by: .symbol).map(\.symbol) == ["ABCD", "EFGH", "MNOP", "QRST", "UVWX"])
  }

  @Test func quoteAgeOldestFirstUnknownLast() throws {
    // 2.5 s, 1.2 s, then the two 0.4 s rows closest first, then the row without a quote age.
    #expect(WatchingList.sorted(try rows(), by: .quoteAge).map(\.symbol) == ["QRST", "ABCD", "UVWX", "MNOP", "EFGH"])
  }

  @Test func latestDecisionFirst() throws {
    // 15:04, then the two 15:02 rows closest first, 15:01, 15:00.
    #expect(WatchingList.sorted(try rows(), by: .latest).map(\.symbol) == ["EFGH", "UVWX", "MNOP", "QRST", "ABCD"])
  }

  @Test func ordersDoNotDependOnInputOrder() throws {
    let forward = try rows()
    for sort in WatchingSort.allCases {
      #expect(WatchingList.sorted(forward, by: sort) == WatchingList.sorted(forward.reversed(), by: sort))
    }
  }
}
