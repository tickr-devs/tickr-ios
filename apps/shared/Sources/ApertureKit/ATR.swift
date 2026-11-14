import Foundation

public extension Indicators {
  /// Period of the ATR line, in M1 bars (price-action-v1's atr_period).
  static let atrPeriod = 14

  /// true_range_series: the first bar has no previous close, so its range is high - low.
  static func trueRange(_ bars: [BarV1]) -> [Double] {
    var previousClose: Double?
    return bars.map { bar in
      let high = Candles.double(bar.high)
      let low = Candles.double(bar.low)
      defer { previousClose = Candles.double(bar.close) }
      guard let close = previousClose else { return high - low }
      return max(high - low, abs(high - close), abs(low - close))
    }
  }

  /// atr_series: Wilder average true range. The first value, at the `period`-th bar, is the
  /// simple average of the first `period` true ranges; then `atr = (prev * (period - 1) + tr) / period`.
  static func atr(_ bars: [BarV1], period: Int) -> [Double?] {
    guard period > 0 else { return bars.map { _ in nil } }
    let ranges = trueRange(bars)
    var previous: Double?
    var sum = 0.0
    return ranges.enumerated().map { index, range in
      sum += range
      if index + 1 < period { return nil }
      let next = previous.map { ($0 * Double(period - 1) + range) / Double(period) } ?? sum / Double(period)
      previous = next
      return next
    }
  }
}

public extension ChartSeries {
  /// The ATR line, one value per candle: the M1 ATR at each candle's last bar, like the other lines.
  /// It warms up on the shown day's bars only, so the first `atrPeriod` M1 bars have no value; the
  /// bot may also have seen earlier bars.
  static func atr(bars: [BarV1], timeframe: Timeframe) -> [Double?] {
    let values = Indicators.atr(bars, period: Indicators.atrPeriod)
    return Candles.groups(bars, timeframe: timeframe).map { values[$0.lastBar] }
  }
}
