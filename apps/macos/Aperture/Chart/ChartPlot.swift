import ApertureKit
import Foundation
import Observation

/// Candles, lines and ATR of one day's bars in one timeframe. Built once per new bars or timeframe
/// (`ChartModel.plot(timeframe:)`), not on every redraw: a scroll or a zoom redraws many times a
/// second, and building the series converts every bar's decimals again.
struct ChartPlot: Sendable {
  /// Which read of the bars this was built from (`ChartModel.revision`).
  let revision: Int
  let series: ChartSeries
  let atr: [Double?]

  init(bars: [BarV1], timeframe: Timeframe, revision: Int) {
    self.revision = revision
    series = ChartSeries(bars: bars, timeframe: timeframe)
    atr = ChartSeries.atr(bars: bars, timeframe: timeframe)
  }

  var timeframe: Timeframe { series.timeframe }
  var candles: [Candle] { series.candles }

  /// Indices of the candles that overlap `start..<end` (candles are oldest first, so this is a
  /// binary search, not a scan of the day).
  func indices(from start: Date, to end: Date) -> Range<Int> {
    let lower = boundary { $0.end > start }
    let upper = boundary { $0.start >= end }
    return lower..<max(lower, upper)
  }

  /// Index of the candle whose slot holds `time`, if any.
  func index(at time: Date) -> Int? {
    let index = boundary { $0.end > time }
    return index < candles.count && candles[index].start <= time ? index : nil
  }

  /// First index whose candle meets `test`, which must hold for every candle after it too.
  private func boundary(_ test: (Candle) -> Bool) -> Int {
    var low = 0
    var high = candles.count
    while low < high {
      let middle = (low + high) / 2
      if test(candles[middle]) { high = middle } else { low = middle + 1 }
    }
    return low
  }
}

/// The candle under the pointer. Kept apart from the chart's own state so that moving the pointer
/// redraws only the crosshair and the readout, not every candle of the day.
@MainActor @Observable
final class ChartPointer {
  /// Index of the pointed candle in the plot's candles.
  var index: Int?
  /// The pointed time as the chart last reported it; not observed, so the chart reading it back
  /// does not redraw on every pointer move.
  @ObservationIgnored var time: Date?
}
