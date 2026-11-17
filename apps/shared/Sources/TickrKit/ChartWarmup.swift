import Foundation

/// The candles of a range beyond one day with every line and study computed over the earlier
/// candles of a longer read too (`ChartRange.warmup`), so an EMA, MACD or RSI starts at the left
/// edge instead of after its period. Only the range's own candles are kept, and only those of
/// the regular session (`regularSession`).
public struct WarmChart: Sendable {
  /// The range's candles at their real times, with their lines.
  public let series: ChartSeries
  public let studies: CandleStudies
  public let atr: [Double?]
  /// Candles of the warm-up read before the range's first one.
  public let warmupCount: Int

  /// `warmup` counts only when it is the same symbol in the same candles; its candles from the
  /// range's first one on are replaced by the range's own (the newer read).
  public init(chart: ChartV1, warmup: ChartV1?) {
    let shown = Self.regularSession(chart.bars)
    var earlier: [ChartBarV1] = []
    if let warmup, warmup.symbol == chart.symbol, warmup.interval == chart.interval,
      let first = shown.first?.start.date {
      earlier = Self.regularSession(warmup.bars).filter { $0.start.date < first }
    }
    let full = ChartSeries(chartBars: earlier + shown, interval: chart.interval)
    warmupCount = earlier.count
    series = full.dropping(earlier.count)
    studies = CandleStudies(candles: full.candles).dropping(earlier.count)
    atr = Array(ChartSeries.atr(candles: full.candles).dropFirst(earlier.count))
  }

  /// The candles of the regular session: GET /chart's 5D candles include the pre-market (04:00)
  /// and after-hours (to 20:00), which are more than half of every day's candles with about a
  /// hundredth of its volume, so the regular sessions shrank to narrow strips between thin ones.
  /// The Chart boards draw the regular session only (09:30 to 16:00), as the 1D range's captured
  /// bars are; daily, weekly and monthly candles are never extended.
  public static func regularSession(_ bars: [ChartBarV1]) -> [ChartBarV1] {
    bars.filter { !$0.extended }
  }
}
