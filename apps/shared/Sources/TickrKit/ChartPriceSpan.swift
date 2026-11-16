import Foundation

/// The prices a chart's price scale must hold so that everything drawn over the candles on
/// screen stays inside the plot: a VWAP or EMA far from the price is part of the picture, not a
/// line running off the top of the chart.
public enum ChartPriceSpan {
  /// Lowest and highest of the candles at `shown` (their lows and highs), the values at `shown`
  /// of each drawn line in `lines` (one value per candle, nil where the line is not defined yet)
  /// and the `levels` drawn across the chart (an entry, a stop). Values that are not finite are
  /// left out. Nil when there is no price at all. The caller adds its own padding.
  public static func bounds(
    of candles: [Candle], shown: Range<Int>, lines: [[Double?]] = [], levels: [Double] = []
  ) -> ClosedRange<Double>? {
    let onScreen = shown.clamped(to: candles.indices)
    var low = Double.infinity
    var high = -Double.infinity
    func take(_ price: Double) {
      guard price.isFinite else { return }
      low = min(low, price)
      high = max(high, price)
    }
    for index in onScreen {
      take(candles[index].low)
      take(candles[index].high)
    }
    for line in lines {
      for index in onScreen.clamped(to: line.indices) {
        if let value = line[index] { take(value) }
      }
    }
    levels.forEach(take)
    guard low <= high else { return nil }
    return low...high
  }
}
