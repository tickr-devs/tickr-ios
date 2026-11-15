@testable import ApertureKit
import Foundation
import Testing

@Suite("Chart studies: moving averages, Bollinger, MACD, RSI, stochastic")
struct StudiesTests {
  func near(_ value: Double?, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < tolerance
  }

  /// A one-minute candle at minute `minute` from its prices.
  func candle(_ minute: Int, open: Double, high: Double, low: Double, close: Double) -> Candle {
    let start = Date(timeIntervalSince1970: TimeInterval(minute * 60))
    return Candle(
      start: start, end: start.addingTimeInterval(60), open: open, high: high, low: low, close: close, volume: 100)
  }

  @Test("SMA averages the last period values and is undefined before")
  func simpleAverage() {
    let values = Studies.sma([1, 2, 3, 4, 5], period: 3)
    #expect(values[0] == nil)
    #expect(values[1] == nil)
    #expect(near(values[2], 2))
    #expect(near(values[3], 3))
    #expect(near(values[4], 4))
  }

  @Test("SMA over a line that starts undefined keeps the leading gap")
  func averageOfPartialLine() {
    let values = Studies.sma([nil, nil, 2, 4, 6] as [Double?], period: 2)
    #expect(values[0] == nil)
    #expect(values[2] == nil)
    #expect(near(values[3], 3))
    #expect(near(values[4], 5))
  }

  @Test("Bollinger lines sit two population deviations from the SMA")
  func bollinger() {
    let bands = Studies.bollinger([2, 4, 4, 4, 5, 5, 7, 9], period: 8, width: 2)
    #expect(bands[6] == nil)
    // Mean 5, population deviation 2 (the textbook example).
    #expect(near(bands[7]?.middle, 5))
    #expect(near(bands[7]?.upper, 9))
    #expect(near(bands[7]?.lower, 1))
  }

  @Test("RSI follows Wilder's smoothing")
  func rsi() {
    // Changes +1, +1, -1, +2: first averages gain 2/3, loss 1/3 over three changes.
    let values = Studies.rsi([10, 11, 12, 11, 13], period: 3)
    #expect(values.count == 5)
    #expect(values[2] == nil)
    #expect(near(values[3], 100 - 100 / (1 + 2.0)))
    // gain (2/3 * 2 + 2) / 3 = 10/9, loss (1/3 * 2) / 3 = 2/9: RS 5.
    #expect(near(values[4], 100 - 100 / 6.0))
  }

  @Test("RSI is 100 when nothing fell, 50 when nothing moved, and undefined for too few closes")
  func rsiEdges() {
    #expect(near(Studies.rsi([1, 2, 3, 4], period: 3)[3], 100))
    #expect(near(Studies.rsi([5, 5, 5, 5], period: 3)[3], 50))
    #expect(Studies.rsi([1, 2, 3], period: 3).allSatisfy { $0 == nil })
  }

  /// StockCharts' EMA worksheet closes (the classic 10-day example).
  static let closes = [22.27, 22.19, 22.08, 22.17, 22.18, 22.13, 22.23, 22.43, 22.24, 22.29, 22.15, 22.39]

  @Test("Charting EMA is SMA-seeded and matches StockCharts' worksheet")
  func chartingEMA() {
    let values = Studies.ema(Self.closes, period: 10)
    #expect(values[8] == nil)
    #expect(near(values[9], 22.221))
    #expect(near(values[10], 22.20809090909091))
    #expect(near(values[11], 22.241165289256198))
    #expect(Studies.ema([1, 2], period: 3).allSatisfy { $0 == nil })
  }

  @Test("MACD uses SMA-seeded EMAs; the signal starts signal - 1 values after the MACD line")
  func macd() {
    // Reference: MACD(3, 5, 3) computed with the standard definition (SMA-seeded EMAs).
    let points = Studies.macd(Self.closes, fast: 3, slow: 5, signal: 3)
    #expect(points[5] == nil)
    #expect(near(points[6]?.macd, 0.0072083333, tolerance: 1e-9))
    #expect(near(points[6]?.signal, -0.0005138889, tolerance: 1e-9))
    #expect(near(points[7]?.macd, 0.0444930556, tolerance: 1e-9))
    #expect(near(points[7]?.signal, 0.0219895833, tolerance: 1e-9))
    #expect(near(points[11]?.macd, 0.0205525924, tolerance: 1e-9))
    #expect(near(points[11]?.signal, 0.0114100893, tolerance: 1e-9))
    #expect(near(points[11]?.histogram, 0.0205525924 - 0.0114100893, tolerance: 1e-9))
  }

  @Test("Slow stochastic smooths fast %K, and %D smooths slow %K")
  func stochastic() {
    let candles = [
      candle(0, open: 1, high: 2, low: 0, close: 1),
      candle(1, open: 1, high: 4, low: 1, close: 4),
      candle(2, open: 4, high: 4, low: 2, close: 3),
      candle(3, open: 3, high: 3, low: 1, close: 1),
    ]
    let points = Studies.slowStochastic(candles, period: 2, smoothing: 2)
    // Fast %K: -, 100 (4 in 0...4), 66.67 (3 in 1...4), 0 (1 in 1...4).
    #expect(points[1] == nil)
    #expect(points[2] == nil)
    #expect(near(points[3]?.k, (200.0 / 3 + 0) / 2))
    #expect(near(points[3]?.d, ((100 + 200.0 / 3) / 2 + (200.0 / 3) / 2) / 2))
  }

  @Test("A flat range puts the stochastic in the middle")
  func flatStochastic() {
    let flat = (0..<3).map { candle($0, open: 5, high: 5, low: 5, close: 5) }
    let points = Studies.slowStochastic(flat, period: 1, smoothing: 1)
    #expect(near(points[2]?.k, 50))
  }

  @Test("Extremes find the highest high and lowest low in the visible range")
  func extremes() {
    let candles = [
      candle(0, open: 5, high: 9, low: 1, close: 5),
      candle(1, open: 5, high: 7, low: 4, close: 6),
      candle(2, open: 6, high: 8, low: 3, close: 7),
      candle(3, open: 7, high: 8, low: 3, close: 7),
    ]
    let all = candles.extremes(in: 0..<4)
    #expect(all?.high == 0)
    #expect(all?.low == 0)
    let tail = candles.extremes(in: 1..<10)
    #expect(tail?.high == 2)
    #expect(tail?.low == 2)
    #expect(candles.extremes(in: 4..<4) == nil)
  }

  @Test("Change compares with the previous close, the first candle with its open")
  func change() {
    let candles = [
      candle(0, open: 4, high: 5, low: 4, close: 5),
      candle(1, open: 5, high: 5, low: 4, close: 4),
    ]
    #expect(near(candles.change(at: 0)?.amount, 1))
    #expect(near(candles.change(at: 0)?.fraction, 0.25))
    #expect(near(candles.change(at: 1)?.amount, -1))
    #expect(near(candles.change(at: 1)?.fraction, -0.2))
    #expect(candles.change(at: 2) == nil)
  }

  @Test("CandleStudies builds one line per moving-average period")
  func allStudies() {
    let candles = (0..<40).map { candle($0, open: Double($0), high: Double($0) + 1, low: Double($0) - 1, close: Double($0)) }
    let studies = CandleStudies(candles: candles)
    #expect(studies.movingAverages.count == Studies.movingAveragePeriods.count)
    #expect(studies.rsi.count == candles.count)
    #expect(near(studies.rsi.last ?? nil, 100))
    #expect(studies.macd.last != nil)
  }
}
