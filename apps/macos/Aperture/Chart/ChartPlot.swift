import ApertureKit
import Foundation
import Observation

/// Candles, lines, ATR and studies of one day's bars, or of a longer range read from GET /chart,
/// in one timeframe. Built once per new read, range or timeframe (`ChartModel.plot`), not on every
/// redraw: a scroll or a zoom redraws many times a second, and building the series converts every
/// bar's decimals again.
struct ChartPlot: Sendable {
  /// Which read of the bars this was built from (`ChartModel.revision`).
  let revision: Int
  /// The range shown: one day's bars, or several sessions or months.
  let range: ChartRange
  /// The candles drawn. Over a range beyond one day they sit back to back (`gapless()`), with
  /// no overnight, weekend or holiday gaps; `starts` keeps their real times.
  let series: ChartSeries
  /// Real opening time of each candle, for the time axis, the crosshair and the readout.
  let starts: [Date]
  /// Labelled times on the time axis of a range beyond one day: where a session, week, month
  /// or quarter begins. Empty for one day, whose axis shows clock times.
  let axisMarks: [ChartAxisMark]
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

  /// One day's M1 bars (GET /bars) in `timeframe`, on the day's own clock.
  init(bars: [BarV1], timeframe: Timeframe, revision: Int) {
    let series = ChartSeries(bars: bars, timeframe: timeframe)
    self.init(
      series: series, atr: ChartSeries.atr(bars: bars, timeframe: timeframe), starts: series.candles.map(\.start),
      range: .oneDay, revision: revision)
  }

  /// Candles of a GET /chart answer, back to back.
  init(chart: ChartV1, revision: Int) {
    let real = ChartSeries(chart: chart)
    self.init(
      series: real.gapless(), atr: ChartSeries.atr(candles: real.candles), starts: real.candles.map(\.start),
      range: chart.range, revision: revision)
  }

  private init(series: ChartSeries, atr: [Double?], starts: [Date], range: ChartRange, revision: Int) {
    self.revision = revision
    self.range = range
    self.series = series
    self.atr = atr
    self.starts = starts
    axisMarks = range == .oneDay ? [] : ChartAxisMark.marks(starts: starts, drawn: series.candles, range: range, timeframe: series.timeframe)
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

  /// The candle's real time as the readout and the crosshair show it: "14:30" on one day,
  /// "Fri 13 14:30" over five days, "Fri Nov 13" for a daily candle, the week's Monday for a
  /// weekly one, "Nov 2026" for a monthly one.
  func timeText(_ index: Int) -> String {
    guard starts.indices.contains(index) else { return Format.missing }
    let start = starts[index]
    switch timeframe {
    case .d1: return Format.chartDay(start)
    case .w1: return Format.chartMonthDay(start)
    case .mo1: return Format.chartMonthYear(start)
    default: return range == .oneDay ? Format.marketMinute(start) : Format.chartSessionMinute(start)
    }
  }

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

/// A labelled time on the axis of a range beyond one day: the drawn (back-to-back) time of the
/// first candle of a session, week, month or quarter, with that real date as its label.
struct ChartAxisMark: Hashable, Sendable {
  let time: Date
  let text: String

  /// The first candle (the left edge included) of each session over five days, of each week over
  /// a month, of each month over three months or a year (of each quarter for monthly candles), or
  /// of a finer period when the range has too few candles for those (`ChartAxis.labels`).
  static func marks(starts: [Date], drawn: [Candle], range: ChartRange, timeframe: Timeframe) -> [ChartAxisMark] {
    let labels = ChartAxis.labels(starts, range: range, timeframe: timeframe)
    return labels.indices
      .filter { drawn.indices.contains($0) }
      .map { ChartAxisMark(time: drawn[$0].start, text: label(starts[$0], period: labels.period, range: range)) }
  }

  /// "Fri 13" for a session over five days, "Nov 9" for a week or a day of a longer range, the
  /// month for a month or quarter.
  private static func label(_ date: Date, period: ChartAxis.Period, range: ChartRange) -> String {
    switch period {
    case .day where range == .fiveDays: Format.chartSessionDay(date)
    case .day, .week: Format.chartMonthDay(date)
    case .month, .quarter: Format.chartMonth(date)
    }
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
