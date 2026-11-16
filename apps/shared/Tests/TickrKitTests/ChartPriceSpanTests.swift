import Foundation
import Testing
@testable import TickrKit

@Suite("What the price scale of a chart holds")
struct ChartPriceSpanTests {
  /// Three one-minute candles trading between 13.09 and 13.20, as AAL did on the day the VWAP
  /// line ran over the symbol chips above the chart.
  static let candles: [Candle] = [(13.10, 13.15), (13.09, 13.18), (13.12, 13.20)].enumerated().map { index, range in
    let start = Date(timeIntervalSince1970: TimeInterval(index * Timeframe.secondsPerMinute))
    return Candle(
      start: start, end: start.addingTimeInterval(TimeInterval(Timeframe.secondsPerMinute)),
      open: range.0, high: range.1, low: range.0, close: range.1, volume: 1)
  }

  @Test("Without lines or levels the span runs from the lowest low to the highest high")
  func candlesOnly() {
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 0..<3) == 13.09...13.20)
  }

  @Test("A VWAP above every candle on screen raises the top to it")
  func vwapAbove() {
    let vwap: [Double?] = [13.34, 13.34, 13.34]
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 0..<3, lines: [vwap]) == 13.09...13.34)
  }

  @Test("An EMA below every candle on screen lowers the bottom to it")
  func emaBelow() {
    let ema: [Double?] = [nil, 12.95, 13.01]
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 0..<3, lines: [ema]) == 12.95...13.20)
  }

  @Test("Only the values of candles on screen count; nil and non-finite values are left out")
  func onScreenOnly() {
    let line: [Double?] = [14.00, nil, .nan]
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 1..<3, lines: [line]) == 13.09...13.20)
  }

  @Test("A line shorter than the candles counts where it has values")
  func shortLine() {
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 0..<3, lines: [[13.40]]) == 13.09...13.40)
  }

  @Test("Levels across the chart (an entry, a stop) count wherever they are")
  func levels() {
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 0..<3, levels: [12.80, 13.50]) == 12.80...13.50)
  }

  @Test("A range past the candles is cut to them; no price at all gives no span")
  func empty() {
    #expect(ChartPriceSpan.bounds(of: Self.candles, shown: 2..<9) == 13.12...13.20)
    #expect(ChartPriceSpan.bounds(of: [], shown: 0..<3, lines: [[13.0]]) == nil)
    #expect(ChartPriceSpan.bounds(of: [], shown: 0..<0, levels: [13.0]) == 13.0...13.0)
  }
}
