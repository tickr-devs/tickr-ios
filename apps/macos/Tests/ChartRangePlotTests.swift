import Foundation
import Testing
@testable import TickrKit
@testable import TickrMac

@Suite("Chart plot over a range beyond one day")
struct ChartRangePlotTests {
  /// A chart-v1 answer with one bar per start, all at 10 USD.
  func chart(_ interval: String, _ range: String, _ starts: [String]) throws -> ChartV1 {
    let items = starts.map { start in
      """
      {"start": "\(start)", "open": "10", "high": "10", "low": "10", "close": "10", "volume": "100",
       "extended": false}
      """
    }
    let json = """
      {"symbol": "ABCD", "interval": "\(interval)", "range": "\(range)", "source": "demo",
       "cached_at": null, "cause": null, "bars": [\(items.joined(separator: ","))], "api_version": 1}
      """
    return try Wire.decoder().decode(ChartV1.self, from: Data(json.utf8))
  }

  @Test("Five sessions draw back to back with one axis label per session")
  func fiveSessions() throws {
    let plot = ChartPlot(chart: try chart("1h", "5d", [
      "2026-11-13T19:30:00.000Z", "2026-11-13T20:00:00.000Z", "2026-11-16T14:30:00.000Z",
    ]), revision: 0)
    let candles = plot.candles
    #expect(candles[1].start == candles[0].end)
    #expect(candles[2].start == candles[1].end)
    #expect(plot.starts[2] == (try WireTime("2026-11-16T14:30:00.000Z").date))
    #expect(plot.axisMarks.map(\.time) == [candles[0].start, candles[2].start])
    #expect(plot.index(at: candles[2].middle) == 2)
  }

  @Test("A year of monthly candles is labelled once a quarter")
  func monthsByQuarter() throws {
    let starts = (1...12).map { String(format: "2026-%02d-01T05:00:00.000Z", $0) }
    let plot = ChartPlot(chart: try chart("1mo", "1y", starts), revision: 0)
    #expect(plot.axisMarks.count == 4)
    #expect(plot.axisMarks.map(\.time) == [0, 3, 6, 9].map { plot.candles[$0].start })
  }

  @Test("A month of a few sessions is labelled by day, not by its two weeks")
  func fewSessionsByDay() throws {
    let starts = ["06", "09", "10", "11", "12", "13"].map { "2026-11-\($0)T05:00:00.000Z" }
    let plot = ChartPlot(chart: try chart("1d", "1m", starts), revision: 0)
    #expect(plot.axisMarks.count == starts.count)
  }

  @Test("One day keeps its own clock and no range labels")
  func oneDay() throws {
    let price = try DecimalString("10")
    let bar = BarV1(
      start: try WireTime("2026-11-16T15:00:00.000Z"), open: price, high: price, low: price, close: price,
      volume: try DecimalString("100"))
    let plot = ChartPlot(bars: [bar], timeframe: .m1, revision: 0)
    #expect(plot.axisMarks.isEmpty)
    #expect(plot.starts == plot.candles.map(\.start))
    #expect(plot.range == .oneDay)
  }
}
