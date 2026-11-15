@testable import ApertureKit
import Foundation
import Testing

@Suite("Position marks from bars")
struct PositionMarksTests {
  /// A bar starting `minute` minutes past 15:00 UTC.
  func bar(_ minute: Int, low: String, high: String, close: String) throws -> BarV1 {
    let json = """
      {"start": "2026-11-16T15:\(String(format: "%02d", minute)):00.000Z", "open": "\(close)",
       "high": "\(high)", "low": "\(low)", "close": "\(close)", "volume": "100"}
      """
    return try Wire.decoder().decode(BarV1.self, from: Data(json.utf8))
  }

  func time(_ minute: Int, second: Int = 0) throws -> Date {
    try Wire.decoder().decode(WireTime.self,
      from: Data("\"2026-11-16T15:\(String(format: "%02d", minute)):\(String(format: "%02d", second)).000Z\"".utf8)).date
  }

  @Test("Bars from the fill's minute on give the last price, result, R, MAE and MFE")
  func marks() throws {
    let bars = [
      try bar(0, low: "9.00", high: "12.00", close: "9.50"),
      try bar(1, low: "9.80", high: "10.20", close: "10.10"),
      try bar(2, low: "9.70", high: "10.60", close: "10.40"),
    ]
    let marks = try #require(PositionMarks(bars: bars, entry: 10, stop: Decimal(string: "9.50"), quantity: 100,
      openedAt: try time(1, second: 30)))
    #expect(marks.last == Decimal(string: "10.40"))
    #expect(marks.unrealized == 40)
    #expect(marks.resultR == Decimal(string: "0.8"))
    #expect(marks.adverse == Decimal(string: "-0.30"))
    #expect(marks.favorable == Decimal(string: "0.60"))
    #expect(marks.adverseR == Decimal(string: "-0.6"))
    #expect(marks.favorableR == Decimal(string: "1.2"))
    #expect(marks.closes.count == 2)
  }

  @Test("Marks are current only while the newest bar closed within the stale limit")
  func freshness() throws {
    let bars = [try bar(2, low: "9.70", high: "10.60", close: "10.40")]
    let marks = try #require(PositionMarks(bars: bars, entry: 10, stop: 9, quantity: 1, openedAt: try time(2)))
    // The bar 15:02 closes at 15:03:00.
    #expect(marks.isFresh(now: try time(3, second: 30), staleSeconds: 30))
    #expect(!marks.isFresh(now: try time(3, second: 31), staleSeconds: 30))
  }

  @Test("No R without a stop below the entry; no marks without a bar since the open")
  func undefined() throws {
    let bars = [try bar(0, low: "10.50", high: "11.00", close: "10.80")]
    let marks = try #require(PositionMarks(bars: bars, entry: 10, stop: nil, quantity: 1, openedAt: try time(0)))
    #expect(marks.resultR == nil)
    #expect(marks.adverse == 0)
    #expect(PositionMarks(bars: bars, entry: 10, stop: 9, quantity: 1, openedAt: try time(5)) == nil)
  }
}
