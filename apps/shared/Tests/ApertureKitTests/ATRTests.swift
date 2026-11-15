@testable import ApertureKit
import Foundation
import Testing

@Suite("Average true range, as the bot computes it")
struct ATRTests {
  /// An M1 bar starting `minute` minutes after 15:00 UTC from its open, high, low and close.
  func bar(_ minute: Int, _ open: String, _ high: String, _ low: String, _ close: String) throws -> BarV1 {
    BarV1(
      start: try WireTime(String(format: "2026-11-16T15:%02d:00.000Z", minute)),
      open: try DecimalString(open), high: try DecimalString(high),
      low: try DecimalString(low), close: try DecimalString(close),
      volume: try DecimalString("100"))
  }

  func near(_ value: Double?, _ expected: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < 1e-9
  }

  /// True ranges 2, 4, 5, 1: the first bar is high - low, later bars reach to the previous close.
  func sample() throws -> [BarV1] {
    [
      try bar(0, "10", "11", "9", "10"),
      try bar(1, "12", "14", "12", "13"),
      try bar(2, "11", "12", "8", "9"),
      try bar(3, "9", "10", "9", "9.5"),
    ]
  }

  @Test("True range uses the previous close after the first bar")
  func trueRange() throws {
    let ranges = Indicators.trueRange(try sample())
    #expect(ranges.count == 4)
    for (range, expected) in zip(ranges, [2.0, 4, 5, 1]) {
      #expect(near(range, expected))
    }
  }

  @Test("ATR starts as a simple average, then smooths like Wilder")
  func wilderSmoothing() throws {
    let values = Indicators.atr(try sample(), period: 2)
    #expect(values[0] == nil)
    #expect(near(values[1], 3))
    #expect(near(values[2], 4))
    #expect(near(values[3], 2.5))
  }

  @Test("Fewer bars than the period give no value")
  func tooFewBars() throws {
    let values = Indicators.atr(try sample(), period: 5)
    #expect(values.allSatisfy { $0 == nil })
  }

  @Test("Each candle takes the M1 ATR at its last bar")
  func sampledPerCandle() throws {
    let bars = try (0..<60).map { minute in try bar(minute, "10", String(11 + minute), "9", "10") }
    let values = Indicators.atr(bars, period: Indicators.atrPeriod)
    let line = ChartSeries.atr(bars: bars, timeframe: .m30)
    #expect(line.count == 2)
    #expect(line[0] == values[29])
    #expect(line[1] == values[59])
    #expect(line[0] != line[1])
  }
}
