import Foundation
import Testing
@testable import TickrKit

@Suite("Chart series from GET /chart (ranges beyond one day)")
struct ChartSeriesRangeTests {
  /// A chart-v1 answer in `interval` with one bar per (start, close, volume); open, high and low
  /// sit around the close.
  func chart(_ interval: String, _ range: String, _ bars: [(String, String, String)]) throws -> ChartV1 {
    let items = bars.map { start, close, volume in
      """
      {"start": "\(start)", "open": "\(close)", "high": "\(close)", "low": "\(close)",
       "close": "\(close)", "volume": "\(volume)", "extended": false}
      """
    }
    let json = """
      {"symbol": "ABCD", "interval": "\(interval)", "range": "\(range)", "source": "webull",
       "cached_at": null, "cause": null, "bars": [\(items.joined(separator: ","))], "api_version": 1}
      """
    return try Wire.decoder().decode(ChartV1.self, from: Data(json.utf8))
  }

  @Test("One candle per chart-v1 bar, keeping its extended flag and the interval's length")
  func candlePerBar() throws {
    let chart = try Wire.decoder().decode(ChartV1.self, from: fixture("chart-v1.json"))
    let series = ChartSeries(chart: chart)
    #expect(series.timeframe == .m5)
    #expect(series.candles.count == chart.bars.count)
    #expect(series.candles.map(\.extended) == [true, true, false])
    #expect(series.candles[0].end.timeIntervalSince(series.candles[0].start) == 300)
    #expect(abs((series.candles.last?.close ?? 0) - 12.47) < 1e-9)
    #expect(series.vwap.count == chart.bars.count)
    #expect(series.fastEMA.count == chart.bars.count)
  }

  @Test("VWAP restarts with each New York session over five days")
  func vwapPerSession() throws {
    let series = ChartSeries(chart: try chart("1h", "5d", [
      ("2026-11-13T19:30:00.000Z", "10", "100"),
      ("2026-11-13T20:00:00.000Z", "20", "100"),
      ("2026-11-16T14:30:00.000Z", "30", "100"),
    ]))
    #expect(series.vwap == [10, 15, 30])
  }

  @Test("Daily, weekly and monthly candles have no VWAP and end on the calendar")
  func calendarCandles() throws {
    let months = ChartSeries(chart: try chart("1mo", "1y", [
      ("2026-01-01T05:00:00.000Z", "10", "1000"),
      ("2026-02-01T05:00:00.000Z", "11", "1000"),
    ]))
    #expect(months.vwap == [nil, nil])
    #expect(months.candles[0].end == (try WireTime("2026-02-01T05:00:00.000Z").date))
    #expect(months.candles[1].end == (try WireTime("2026-03-01T05:00:00.000Z").date))
    let weeks = ChartSeries(chart: try chart("1w", "3m", [("2026-11-09T05:00:00.000Z", "10", "1000")]))
    #expect(weeks.candles[0].end == (try WireTime("2026-11-16T05:00:00.000Z").date))
    // The clocks go back on Nov 1: a New York day is then 25 hours long.
    let days = ChartSeries(chart: try chart("1d", "1m", [("2026-11-01T04:00:00.000Z", "10", "1000")]))
    #expect(days.candles[0].end == (try WireTime("2026-11-02T05:00:00.000Z").date))
  }

  @Test("Gapless candles sit back to back from the first start and keep their values")
  func gapless() throws {
    let series = ChartSeries(chart: try chart("1h", "5d", [
      ("2026-11-13T20:00:00.000Z", "10", "100"),
      ("2026-11-16T14:30:00.000Z", "30", "100"),
    ]))
    let gapless = series.gapless()
    #expect(gapless.candles.map(\.start) == [series.candles[0].start, series.candles[0].start.addingTimeInterval(3600)])
    #expect(gapless.candles[1].end == series.candles[0].start.addingTimeInterval(7200))
    #expect(gapless.candles.map(\.close) == [10, 30])
    #expect(gapless.vwap == series.vwap)
    #expect(gapless.timeframe == .h1)
  }

  @Test("The ATR of a chart-v1 series runs over its own candles")
  func atrOverCandles() throws {
    let bars = (0..<20).map { day in (String(format: "2026-10-%02dT04:00:00.000Z", day + 1), "10", "1000") }
    let series = ChartSeries(chart: try chart("1d", "1m", bars))
    let line = ChartSeries.atr(candles: series.candles)
    #expect(line.count == 20)
    #expect(line[Indicators.atrPeriod - 2] == nil)
    #expect(line[Indicators.atrPeriod - 1] == 0)
  }

  @Test("Axis labels go where a session, week, month or quarter begins")
  func axisBoundaries() throws {
    let date = { (text: String) in try WireTime(text).date }
    let sessions = try ["2026-11-13T19:30:00.000Z", "2026-11-13T20:00:00.000Z", "2026-11-16T14:30:00.000Z"].map(date)
    #expect(ChartAxis.boundaries(sessions, range: .fiveDays, timeframe: .h1) == [0, 2])
    let months = try (1...12).map { try date(String(format: "2026-%02d-01T05:00:00.000Z", $0)) }
    #expect(ChartAxis.boundaries(months, range: .oneYear, timeframe: .mo1) == [0, 3, 6, 9])
    #expect(ChartAxis.boundaries(months, range: .oneYear, timeframe: .d1).count == 12)
    #expect(ChartAxis.boundaries([], range: .oneMonth, timeframe: .d1).isEmpty)
  }

  @Test("A range with too few candles for its own period is labelled by a finer one")
  func finerLabels() throws {
    let date = { (text: String) in try WireTime(text).date }
    // Six sessions over two weeks (Fri Nov 6 to Fri Nov 13): two weeks are too few labels.
    let days = try ["2026-11-06", "2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13"]
      .map { try date("\($0)T05:00:00.000Z") }
    let month = ChartAxis.labels(days, range: .oneMonth, timeframe: .d1)
    #expect(month.period == .day)
    #expect(month.indices == Array(0..<6))
    #expect(ChartAxis.labels(days, range: .threeMonths, timeframe: .d1).period == .day)
    // Three months of sessions keep their months.
    let months = try ["2026-09-01", "2026-09-15", "2026-10-01", "2026-11-02"].map { try date("\($0)T05:00:00.000Z") }
    let quarter = ChartAxis.labels(months, range: .threeMonths, timeframe: .d1)
    #expect(quarter.period == .month)
    #expect(quarter.indices == [0, 2, 3])
  }

  @Test("Clock labels on one day fall on round New York times, at most the asked count on screen")
  func clockMarks() throws {
    let date = { (text: String) in try WireTime(text).date }
    // 09:31 to 10:11 New York (40 one-minute candles): every 10 minutes from 09:40.
    let day = try date("2026-11-13T14:31:00.000Z")...date("2026-11-13T15:11:00.000Z")
    let marks = ChartAxis.clockMarks(in: day, shown: 40 * 60, count: 4)
    #expect(try marks == ["2026-11-13T14:40:00.000Z", "2026-11-13T14:50:00.000Z", "2026-11-13T15:00:00.000Z",
      "2026-11-13T15:10:00.000Z"].map(date))
    // A whole session on screen: hourly at most, still on the hour.
    let session = try date("2026-11-13T14:30:00.000Z")...date("2026-11-13T21:00:00.000Z")
    let hourly = ChartAxis.clockMarks(in: session, shown: 390 * 60, count: 4)
    #expect(hourly.count <= 5)
    #expect(hourly.allSatisfy { WireDate.newYork.component(.minute, from: $0) == 0 })
    #expect(ChartAxis.clockMarks(in: session, shown: 0, count: 4).isEmpty)
  }

  @Test("Labels closer than the gap are left out, a year's start winning over the month before it")
  func spacedLabels() {
    let origin = Date(timeIntervalSince1970: 0)
    let times = [0, 10, 25, 30, 60].map { origin.addingTimeInterval(TimeInterval($0)) }
    #expect(ChartAxis.spaced(times, gap: 20) == [0, 2, 4])
    // Index 3 is preferred: it replaces 2, which sat 5 s before it.
    #expect(ChartAxis.spaced(times, gap: 20, preferred: { $0 == 3 }) == [0, 3, 4])
    #expect(ChartAxis.spaced([], gap: 20).isEmpty)
  }

  @Test("A label hung inward at an end is left out when it would reach its neighbour")
  func hungLabels() {
    let origin = Date(timeIntervalSince1970: 0)
    let shown = origin...origin.addingTimeInterval(100)
    // 0 hangs right from the left edge; 25 is only 1.25 gaps away: 0 goes.
    let times = [0, 25, 50, 75].map { origin.addingTimeInterval(TimeInterval($0)) }
    #expect(ChartAxis.spaced(times, gap: 20, shown: shown) == [1, 2, 3])
    // With room enough, the edge label stays.
    let wide = [0, 40, 70].map { origin.addingTimeInterval(TimeInterval($0)) }
    #expect(ChartAxis.spaced(wide, gap: 20, shown: shown) == [0, 1, 2])
    // At the right end the same: 99 hangs left and sits 9 after 90.
    let late = [50, 90, 99].map { origin.addingTimeInterval(TimeInterval($0)) }
    #expect(ChartAxis.spaced(late, gap: 8, shown: shown) == [0, 1])
  }

  @Test("A year's start hung inward at an end stays; its neighbour gives way")
  func hungYearLabelStays() {
    let origin = Date(timeIntervalSince1970: 0)
    let shown = origin...origin.addingTimeInterval(100)
    // 5 (January, preferred) hangs right from the left edge; 25 is too close: 25 goes, not 5.
    let early = [5, 25, 50, 75].map { origin.addingTimeInterval(TimeInterval($0)) }
    #expect(ChartAxis.spaced(early, gap: 20, shown: shown, preferred: { $0 == 0 }) == [0, 2, 3])
    // The same at the right end.
    let late = [50, 90, 99].map { origin.addingTimeInterval(TimeInterval($0)) }
    #expect(ChartAxis.spaced(late, gap: 8, shown: shown, preferred: { $0 == 2 }) == [0, 2])
  }

  @Test("A label near either end of the shown stretch turns inward")
  func labelAnchors() throws {
    let date = { (text: String) in try WireTime(text).date }
    let shown = try date("2026-11-13T14:30:00.000Z")...date("2026-11-13T15:10:00.000Z")
    #expect(try ChartAxis.anchor(of: date("2026-11-13T14:31:00.000Z"), shown: shown) == .leading)
    #expect(try ChartAxis.anchor(of: date("2026-11-13T14:50:00.000Z"), shown: shown) == .centre)
    #expect(try ChartAxis.anchor(of: date("2026-11-13T15:09:00.000Z"), shown: shown) == .trailing)
  }

  @Test("Lines over a month are warmed up on a year's earlier candles and start at its first candle")
  func warmedUp() throws {
    let days = (1...40).map { String(format: "2026-%02d-%02dT14:30:00.000Z", $0 <= 20 ? 9 : 10, ($0 - 1) % 20 + 1) }
    let bars = days.enumerated().map { index, day in (day, String(10 + index), "100") }
    let year = try chart("1d", "1y", bars)
    let month = try chart("1d", "1m", Array(bars.suffix(15)))
    let cold = WarmChart(chart: month, warmup: nil)
    #expect(cold.studies.rsi.first == .some(nil))
    let warm = WarmChart(chart: month, warmup: year)
    #expect(warm.warmupCount == 25)
    #expect(warm.series.candles.count == 15)
    #expect(warm.series.candles.first?.start == month.bars.first?.start.date)
    #expect(warm.studies.rsi.count == 15)
    #expect(warm.studies.rsi.first.flatMap { $0 } != nil)
    #expect(warm.series.fastEMA.first.flatMap { $0 } != nil)
    // Another symbol or interval is no warm-up.
    #expect(WarmChart(chart: month, warmup: try chart("1w", "1y", bars)).warmupCount == 0)
    #expect(ChartRange.oneMonth.warmup(for: .d1) == .oneYear)
    #expect(ChartRange.oneYear.warmup(for: .d1) == nil)
  }

  @Test("Every offered interval is one GET /chart serves for its range")
  func offeredPairsAreServed() {
    for range in ChartRange.allCases {
      #expect(!range.intervals.isEmpty)
      let intraday = range == .oneDay || range == .fiveDays
      #expect(range.intervals.allSatisfy { $0.isIntraday == intraday })
    }
    #expect(ChartRange.oneDay.intervals == [.m1, .m5, .m30, .h1])
  }
}
