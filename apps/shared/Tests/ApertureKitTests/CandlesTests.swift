@testable import ApertureKit
import Foundation
import Testing

@Suite("Chart candles and indicator lines")
struct CandlesTests {
  /// An M1 bar starting `minute` minutes after 15:00 UTC (with the milliseconds the wire carries)
  /// from its open, high, low, close and volume.
  func bar(_ minute: Int, _ values: String...) throws -> BarV1 {
    BarV1(
      start: try WireTime(String(format: "2026-11-16T15:%02d:00.123Z", minute)),
      open: try DecimalString(values[0]), high: try DecimalString(values[1]),
      low: try DecimalString(values[2]), close: try DecimalString(values[3]),
      volume: try DecimalString(values[4]))
  }

  func near(_ value: Double?, _ expected: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < 1e-9
  }

  @Test("M1 keeps every bar of the fixture, floored to the minute")
  func m1KeepsEveryBar() throws {
    let bars = try Wire.decoder().decode(BarsV1.self, from: fixture("bars-v1.json")).bars
    let candles = Candles.make(bars, timeframe: .m1)
    #expect(candles.count == bars.count)
    #expect(near(candles[0].open, 12.30))
    #expect(near(candles[0].close, 12.36))
    #expect(candles[0].end.timeIntervalSince(candles[0].start) == 60)
    #expect(candles[0].start == (try WireTime("2026-11-16T15:00:00.000Z").date))
  }

  @Test("M5 merges the bars inside each five minutes and keeps gaps")
  func m5MergesAndKeepsGaps() throws {
    let bars = [
      try bar(3, "10", "11", "9.5", "10.5", "100"),
      try bar(4, "10.5", "12", "10", "11", "50"),
      try bar(5, "11", "11.2", "10.8", "11.1", "10"),
      try bar(16, "12", "12", "12", "12", "5"),
    ]
    let candles = Candles.make(bars, timeframe: .m5)
    // 15:00, 15:05 and 15:15; no candle for the empty 15:10.
    #expect(candles.count == 3)
    #expect(candles[0].open == 10)
    #expect(candles[0].high == 12)
    #expect(candles[0].low == 9.5)
    #expect(candles[0].close == 11)
    #expect(candles[0].volume == 150)
    #expect(candles[0].isUp)
    #expect(candles[0].start == (try WireTime("2026-11-16T15:00:00.000Z").date))
    #expect(candles[2].start == (try WireTime("2026-11-16T15:15:00.000Z").date))
  }

  @Test("VWAP is the bot's vwap_series over M1 bars and waits for volume")
  func vwap() throws {
    let bars = [
      try bar(0, "10", "10", "10", "10", "0"),
      try bar(1, "10", "12", "9", "12", "100"),
      try bar(2, "12", "14", "11", "14", "300"),
    ]
    let vwap = Indicators.vwap(bars)
    #expect(vwap[0] == nil)
    #expect(near(vwap[1], 11))
    #expect(near(vwap[2], (11.0 * 100 + 13 * 300) / 400))
  }

  @Test("EMA is the bot's ema_series: seeded with the first value, then smoothed")
  func ema() {
    let ema = Indicators.ema([1, 2, 3, 4], period: 3)
    #expect(near(ema[0], 1))
    #expect(near(ema[1], 1.5))
    #expect(near(ema[2], 2.25))
    #expect(near(ema[3], 3.125))
    #expect(Indicators.ema([1, 2], period: 0).allSatisfy { $0 == nil })
  }

  @Test("A timeframe shows the M1 lines at each candle's last M1 bar, not lines of the candles")
  func seriesSamplesTheM1Lines() throws {
    let bars = [
      try bar(0, "10", "10", "10", "10", "100"),
      try bar(1, "10", "13", "10", "13", "100"),
      try bar(2, "13", "13", "7", "7", "400"),
      try bar(5, "7", "8", "7", "8", "100"),
    ]
    let series = ChartSeries(bars: bars, timeframe: .m5)
    let m1VWAP = Indicators.vwap(bars)
    let m1Fast = Indicators.ema(bars.map { Candles.double($0.close) }, period: Indicators.fastEMAPeriod)
    #expect(series.candles.count == 2)
    #expect(series.vwap == [m1VWAP[2], m1VWAP[3]])
    #expect(series.fastEMA == [m1Fast[2], m1Fast[3]])
    // A VWAP of the M5 candle itself (typical price (13 + 7 + 7) / 3 = 9) would differ.
    #expect(!near(series.vwap[0], 9))
  }

  @Test("H1 candles start at the 09:30 open, not on clock hours")
  func hourFromTheOpen() throws {
    // 15:00 UTC is 10:00 in New York on 2026-11-16 (EST): the 09:30 candle.
    let bars = [
      try bar(0, "10", "11", "9", "10.5", "100"),
      try bar(29, "10.5", "12", "10", "11", "50"),
      try bar(30, "11", "11", "11", "11", "10"),
    ]
    let candles = Candles.make(bars, timeframe: .h1)
    #expect(candles.count == 2)
    #expect(candles[0].start == (try WireTime("2026-11-16T14:30:00.000Z").date))
    #expect(candles[0].volume == 150)
    #expect(candles[1].start == (try WireTime("2026-11-16T15:30:00.000Z").date))
    #expect(candles[1].end == (try WireTime("2026-11-16T16:30:00.000Z").date))
  }

  @Test("The 16:00 bar starts a new candle; the 15:30 H1 candle ends at the close")
  func hourStopsAtTheClose() throws {
    // 20:59 UTC is 15:59 and 21:00 UTC is 16:00 in New York on 2026-11-16 (EST).
    let bars = [
      try BarV1(
        start: try WireTime("2026-11-16T20:59:00.000Z"), open: try DecimalString("10"),
        high: try DecimalString("10"), low: try DecimalString("10"), close: try DecimalString("10"),
        volume: try DecimalString("1")),
      try BarV1(
        start: try WireTime("2026-11-16T21:00:00.000Z"), open: try DecimalString("11"),
        high: try DecimalString("11"), low: try DecimalString("11"), close: try DecimalString("11"),
        volume: try DecimalString("1")),
    ]
    let candles = Candles.make(bars, timeframe: .h1)
    #expect(candles.count == 2)
    #expect(candles[0].start == (try WireTime("2026-11-16T20:30:00.000Z").date))
    #expect(candles[0].end == (try WireTime("2026-11-16T21:00:00.000Z").date))
    #expect(candles[1].start == (try WireTime("2026-11-16T21:00:00.000Z").date))
  }

  @Test("Pre-market candles count from 04:00")
  func preMarketFromFour() throws {
    // 13:10 UTC is 08:10 in New York: the H1 candle from 08:00, not 07:30.
    let bars = [
      try BarV1(
        start: try WireTime("2026-11-16T13:10:00.000Z"), open: try DecimalString("10"),
        high: try DecimalString("10"), low: try DecimalString("10"), close: try DecimalString("10"),
        volume: try DecimalString("1")),
    ]
    let candles = Candles.make(bars, timeframe: .h1)
    #expect(candles.first?.start == (try WireTime("2026-11-16T13:00:00.000Z").date))
  }

  @Test("Whole-hour timeframes name their hours")
  func hours() {
    #expect(Timeframe.h1.hours == 1)
    #expect(Timeframe.m30.hours == nil)
    #expect(Timeframe.m1.hours == nil)
    #expect(Timeframe.h1.seconds == 3600)
  }
}
