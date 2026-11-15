import ApertureKit
import Foundation
import Observation

/// Candles, lines, ATR and studies of one day's bars in one timeframe. Built once per new bars or timeframe
/// (`ChartModel.plot(timeframe:)`), not on every redraw: a scroll or a zoom redraws many times a
/// second, and building the series converts every bar's decimals again.
struct ChartPlot: Sendable {
  /// Which read of the bars this was built from (`ChartModel.revision`).
  let revision: Int
  let series: ChartSeries
  let atr: [Double?]
  /// Moving averages, Bollinger, MACD, RSI and stochastic of the candles, split into one array
  /// per drawn line so a redraw only looks values up.
  let movingAverages: [[Double?]]
  let bollingerUpper: [Double?]
  let bollingerMiddle: [Double?]
  let bollingerLower: [Double?]
  let macd: [Double?]
  let macdSignal: [Double?]
  let macdHistogram: [Double?]
  let rsi: [Double?]
  let stochasticK: [Double?]
  let stochasticD: [Double?]

  init(bars: [BarV1], timeframe: Timeframe, revision: Int) {
    self.revision = revision
    series = ChartSeries(bars: bars, timeframe: timeframe)
    atr = ChartSeries.atr(bars: bars, timeframe: timeframe)
    let studies = CandleStudies(candles: series.candles)
    movingAverages = studies.movingAverages
    bollingerUpper = studies.bollinger.map { $0?.upper }
    bollingerMiddle = studies.bollinger.map { $0?.middle }
    bollingerLower = studies.bollinger.map { $0?.lower }
    macd = studies.macd.map { $0?.macd }
    macdSignal = studies.macd.map { $0?.signal }
    macdHistogram = studies.macd.map { $0?.histogram }
    rsi = studies.rsi
    stochasticK = studies.stochastic.map { $0?.k }
    stochasticD = studies.stochastic.map { $0?.d }
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
  /// The pane under the pointer and where in it, for the horizontal line and its value tag.
  var hover: ChartHover?

  /// The pointer moved inside `pane`, to `location` in the pane's own coordinates.
  func move(in pane: ChartPane, to location: CGPoint) {
    hover = ChartHover(pane: pane, location: location)
  }

  /// The pointer left `pane`; a move into the next pane may have been reported first.
  func leave(_ pane: ChartPane) {
    if hover?.pane == pane { hover = nil }
  }
}

/// The stacked panes of the chart, top to bottom.
enum ChartPane: Hashable, Sendable {
  case price
  case macd
  case rsi
  case stochastic
  case atr
}

/// Where the pointer is: its pane and its place in that pane.
struct ChartHover: Equatable {
  let pane: ChartPane
  let location: CGPoint
}
