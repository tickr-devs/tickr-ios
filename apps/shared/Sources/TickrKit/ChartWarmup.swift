import Foundation

/// The candles of a range beyond one day with every line and study computed over the earlier
/// candles of a longer read too (`ChartRange.warmup`), so an EMA, MACD or RSI starts at the left
/// edge instead of after its period. Only the range's own candles are kept: every session's,
/// pre-market and after-hours included.
public struct WarmChart: Sendable {
  /// The range's candles at their real times, with their lines.
  public let series: ChartSeries
  public let studies: CandleStudies
  public let atr: [Double?]
  /// Candles of the warm-up read before the range's first one.
  public let warmupCount: Int

  /// `warmup` counts only when it is the same symbol in the same candles; its candles from the
  /// range's first one on are replaced by the range's own (the newer read). `through`: a recorded
  /// day the range ends on; its later candles (market data always reaches today) are left out, so
  /// a past day never shows the days after it.
  public init(chart: ChartV1, warmup: ChartV1?, through day: WireDate? = nil) {
    let bars = day.map { last in chart.bars.filter { WireDate(newYorkDateOf: $0.start.date) <= last } } ?? chart.bars
    var earlier: [ChartBarV1] = []
    if let warmup, warmup.symbol == chart.symbol, warmup.interval == chart.interval,
      let first = bars.first?.start.date {
      earlier = warmup.bars.filter { $0.start.date < first }
    }
    let full = ChartSeries(chartBars: earlier + bars, interval: chart.interval)
    warmupCount = earlier.count
    series = full.dropping(earlier.count)
    studies = CandleStudies(candles: full.candles).dropping(earlier.count)
    atr = Array(ChartSeries.atr(candles: full.candles).dropFirst(earlier.count))
  }
}
