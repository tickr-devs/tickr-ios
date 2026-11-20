import Foundation
import Observation
import TickrDesign
import TickrKit

/// Candles, lines, ATR and studies of one day's bars, or of a longer range read from GET /chart,
/// in one timeframe. Built once per new read, range or timeframe (`ChartModel.plot`), not on every
/// redraw: a scroll or a zoom redraws many times a second, and building the series converts every
/// bar's decimals again.
struct ChartPlot: Sendable {
  /// Which read of the bars this was built from (`ChartModel.revision`).
  let revision: Int
  /// The range shown: one day's bars, or several sessions or months.
  let range: ChartRange
  /// The candles drawn, back to back (`gapless()`): no overnight, weekend or holiday gap and no
  /// hole for a minute without trades, on every range (mockup v113); `real` and `starts` keep
  /// their real times.
  let series: ChartSeries
  /// The same candles at their real times, index for index.
  let real: [Candle]
  /// Real opening time of each candle, for the time axis, the crosshair and the readout.
  let starts: [Date]
  /// Where a real time (a trade, a decision, the position's entry) is drawn.
  let clock: GaplessClock
  /// Day and 5D: the parts of the day (bands, boundaries, the time axis), with the rest of today
  /// reserved on today's Day chart; nil for daily, weekly and monthly candles.
  let sessions: SessionAxis?
  /// Today's session from the calendar, whose rest the Day chart reserves; nil otherwise.
  let today: SessionSpan?
  /// The extended close the Day axis ends on ("After 20:00"): today's from the calendar, else
  /// the last candle's end.
  let extendedClose: Date?
  /// Labelled times on the time axis of a month or longer: where a week, month or quarter begins.
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
  /// Mean volume of the last `volumeAveragePeriod` candles, for the volume pane's average line
  /// and relative volume.
  let volumeAverage: [Double?]
  /// The shapes of the readout's figures over all the candles, so each keeps one width while the
  /// pointer moves (`ChartReadout`).
  let readoutShapes: ReadoutShapes
  /// The shapes of the readout's time over all the candles (`timeText`).
  private(set) var timeShapes: [String] = []

  /// Candles the volume average spans.
  static let volumeAveragePeriod = 20

  /// A recorded day's M1 bars (GET /bars, the bot's capture) in `timeframe`.
  init(bars: [BarV1], timeframe: Timeframe, revision: Int) {
    let series = ChartSeries(bars: bars, timeframe: timeframe)
    self.init(
      real: series, atr: ChartSeries.atr(bars: bars, timeframe: timeframe), studies: CandleStudies(candles: series.candles),
      range: .oneDay, today: nil, afterSlots: nil, revision: revision)
  }

  /// Candles of a GET /chart answer, their lines and studies warmed up on the earlier candles of
  /// `warmup` (`WarmChart`). `today`: the calendar's session of today, on today's Day chart, whose
  /// rest is reserved up to the extended close. `through`: the recorded day the range ends on.
  init(chart: ChartV1, warmup: ChartV1? = nil, today: SessionSpan? = nil, through: WireDate? = nil, revision: Int) {
    let warm = WarmChart(chart: chart, warmup: warmup, through: through)
    self.init(
      real: warm.series, atr: warm.atr, studies: warm.studies, range: chart.range,
      today: chart.range == .oneDay ? today : nil, afterSlots: chart.previousAfterCandles, revision: revision)
  }

  private init(
    real: ChartSeries, atr: [Double?], studies: CandleStudies, range: ChartRange, today: SessionSpan?,
    afterSlots: Int?, revision: Int
  ) {
    self.revision = revision
    self.range = range
    let series = real.gapless()
    self.series = series
    self.real = real.candles
    self.atr = atr
    starts = real.candles.map(\.start)
    clock = GaplessClock(real: real)
    let intraday = real.timeframe.isIntraday
    self.today = today
    sessions = intraday ? SessionAxis(candles: real.candles, timeframe: real.timeframe, today: today, afterSlots: afterSlots)
      : nil
    extendedClose = intraday ? (today?.end ?? real.candles.last?.end) : nil
    axisMarks = intraday
      ? [] : ChartAxisMark.marks(starts: starts, drawn: series.candles, range: range, timeframe: series.timeframe)
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
    volumeAverage = Studies.sma(series.candles.map(\.volume), period: Self.volumeAveragePeriod)
    readoutShapes = ReadoutShapes(series.candles)
    timeShapes = FigureShapes.shapes(Self.runEnds(real.candles, timeframe: real.timeframe).map { timeText($0) })
  }

  /// The first and last candle of each run of one part of the day without a gap: the times that
  /// stand for every time's shape in `timeText` (a part's name, a day's name over several days).
  static func runEnds(_ candles: [Candle], timeframe: Timeframe) -> [Int] {
    var ends: [Int] = []
    for index in candles.indices {
      let first = index == candles.startIndex || candles[index].session != candles[index - 1].session
        || candles[index].start > candles[index - 1].start.addingTimeInterval(timeframe.seconds)
      if first {
        if index > candles.startIndex { ends.append(index - 1) }
        ends.append(index)
      }
    }
    if let last = candles.indices.last { ends.append(last) }
    return ends
  }

  /// The drawn start of slot `slot` (a candle's, or a reserved one's after the last candle).
  func slotTime(_ slot: Int) -> Date {
    (series.candles.first?.start ?? .distantPast).addingTimeInterval(Double(slot) * series.timeframe.seconds)
  }

  /// Where the drawn time axis ends: after the last candle, or after today's reserved slots.
  var drawnEnd: Date {
    guard let sessions else { return series.candles.last?.end ?? .distantPast }
    return slotTime(sessions.slots)
  }

  /// Where a real time is drawn (`clock`); nil before the first candle.
  func drawnTime(_ time: Date) -> Date? { clock.drawn(time) }

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
    default:
      let time = range == .oneDay ? Format.marketMinute(start) : Format.chartSessionMinute(start)
      // "19:50 · after-hours" (mockup v113).
      let part: LocalizedStringResource? =
        switch real[index].session {
        case .pre: ChartSessionWords.preMarket
        case .after: ChartSessionWords.afterHours
        case .regular, nil: nil
        }
      return part.map { "\(time)\(Format.itemSeparator)\(String(localized: $0))" } ?? time
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
  /// Where a year begins: kept over a month label it would collide with.
  var major = false
  /// How a session axis's label hangs from its time (mockup v113).
  var anchor: ChartAxis.Anchor = .centre
  /// A session, its end or a day's name, drawn stronger than a round time.
  var strong = false
  /// How far the label's left edge sits from its time, in points (placed by `AxisLabelPlacer`).
  var offset: CGFloat = 0

  /// The first candle (the left edge included) of each session over five days, of each week over
  /// a month, of each month over three months or a year (of each quarter for monthly candles), or
  /// of a finer period when the range has too few candles for those (`ChartAxis.labels`).
  static func marks(starts: [Date], drawn: [Candle], range: ChartRange, timeframe: Timeframe) -> [ChartAxisMark] {
    let labels = ChartAxis.labels(starts, range: range, timeframe: timeframe)
    return labels.indices
      .filter { drawn.indices.contains($0) }
      .map { index in
        let january = WireDate.newYork.component(.month, from: starts[index]) == 1
        return ChartAxisMark(
          time: drawn[index].start, text: label(starts[index], period: labels.period, range: range),
          major: january && (labels.period == .month || labels.period == .quarter))
      }
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
  /// A click held the crosshair on its candle (owner, 2026-11-18): the pointer may leave to read
  /// the values, and the crosshair, readout and legend stay on that candle until the next click.
  private(set) var pinned = false

  /// The pointer moved inside `pane`, to `location` in the pane's own coordinates.
  func move(in pane: ChartPane, to location: CGPoint) {
    guard !pinned else { return }
    hover = ChartHover(pane: pane, location: location)
  }

  /// The pointer left `pane`; a move into the next pane may have been reported first.
  func leave(_ pane: ChartPane) {
    guard !pinned else { return }
    if hover?.pane == pane { hover = nil }
  }

  /// A click on the chart: holds the crosshair on the pointed candle, or lets it go again.
  func togglePin() {
    pinned = index != nil && !pinned
  }

  /// Lets the crosshair go: a new symbol, range or day.
  func unpin() {
    pinned = false
  }
}

/// The stacked panes of the chart, top to bottom.
enum ChartPane: Hashable, Sendable {
  case price
  case volume
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
