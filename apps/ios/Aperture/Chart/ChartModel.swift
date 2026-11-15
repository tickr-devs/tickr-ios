import ApertureKit
import Foundation
import Observation

/// What the Chart tab shows: the recorded days, the chosen day's trades and symbols, and the
/// chosen symbol's bars as candles with the bot's indicator lines. Read-only history from the
/// bot's API (GET /days, /days/<date>, /bars); the phone never computes anything the bot acts on.
@MainActor
@Observable
final class ChartModel {
  enum Phase: Equatable {
    case idle
    case loading
    case failed(String)
    case loaded
  }

  /// Seconds between reloads of today's bars while the chart is on screen. The bot captures one
  /// bar a minute, so a few reloads a minute keep the last candle current.
  static let liveReloadSeconds = 15.0
  /// Seconds between reads of five sessions' candles (GET /chart): the bot keeps them a while,
  /// and the shortest candle there is five minutes long.
  static let rangeReloadSeconds = 60.0

  private(set) var phase = Phase.idle
  private(set) var days: [DaySummary] = []
  private(set) var day: DayV1?
  private(set) var bars: BarsV1?
  var selectedDay: WireDate?
  var symbol: String?
  var timeframe = Timeframe.m1 { didSet { rebuild() } }
  /// How far back the chart reaches: the chosen day's recorded bars, or market data over several
  /// sessions or months (GET /chart). Change it with `choose(range:)`.
  private(set) var range = ChartRange.oneDay
  /// The last candles read from GET /chart for the chosen symbol, range and interval.
  private(set) var rangeChart: ChartV1?
  /// A longer read in the same candles whose earlier candles warm the lines up
  /// (`ChartRange.warmup`); nil when the range has none or that read failed.
  private(set) var rangeWarmup: ChartV1?
  /// Why the last GET /chart read failed, if it did (a 503 while market data is off).
  private(set) var rangeFailure: String?
  private(set) var series: ChartSeries?
  /// Real times of `series`' candles and the time axis labels beyond one day.
  private(set) var times = ChartTimes.day
  /// What the trading strategy and the observers decided on the chosen symbol that day.
  private(set) var decisions: DecisionsV1?
  /// Why the decisions could not be read, if they could not; the chart still shows.
  private(set) var decisionsFailure: String?
  /// The symbol and day `decisions` and `decisionsFailure` are about.
  private(set) var decisionsFor: DecisionsKey?

  struct DecisionsKey: Hashable {
    let symbol: String
    let day: WireDate
  }

  /// The decisions of the chosen symbol and day, nil while they are unknown.
  var shownDecisions: DecisionsV1? {
    guard let decisions, decisions.symbol == symbol, decisions.day == selectedDay else { return nil }
    return decisions
  }

  /// Why the chosen symbol's and day's decisions could not be read.
  var shownDecisionsFailure: String? {
    guard let symbol, let selectedDay, decisionsFor == DecisionsKey(symbol: symbol, day: selectedDay) else {
      return nil
    }
    return decisionsFailure
  }
  /// The ATR line for `series`, one value per candle.
  private(set) var atr: [Double?] = []
  /// Moving averages, Bollinger, MACD, RSI and stochastic of `series`' candles.
  private(set) var studies = CandleStudies(candles: [])
  /// Number of the newest load of the days or a day (see `begin()`).
  @ObservationIgnored private var latestRequest = 0

  /// Symbols with captured bars on the chosen day: open positions first, then the symbols traded
  /// that day, then the rest.
  var symbols: [String] {
    guard let day else { return [] }
    return ChartSymbols.ordered(day.barSymbols, open: openSymbols, traded: day.trades.map(\.symbol))
  }
  /// Symbols of the positions the bot holds, when the chosen day is the day of its status.
  var openSymbols: [String] {
    guard let status = Container.shared.appModel().status,
      selectedDay == WireDate(newYorkDateOf: status.writtenAt.date) else { return [] }
    return status.positions.map(\.symbol)
  }
  /// The bot's open position on the chosen symbol, when the chosen day is the day of its status
  /// and that status is fresh; an old status proves nothing about what is open now.
  var openPosition: Position? {
    let app = Container.shared.appModel()
    guard app.isFresh, let symbol, openSymbols.contains(symbol) else { return nil }
    return app.status?.positions.first { $0.symbol == symbol }
  }
  /// Where the trading strategy began watching and said enter on the chosen symbol's candles.
  var events: [ChartEvent] {
    guard range == .oneDay, let series, let decisions = shownDecisions else { return [] }
    return ChartEvent.make(decisions.decisions, candles: series.candles)
  }
  /// Trades of the chosen symbol closed on the chosen day.
  var trades: [DayTrade] { day?.trades.filter { $0.symbol == symbol } ?? [] }
  /// Whether the chosen day is today in New York on the bot's clock, so its bars still grow.
  var isToday: Bool { selectedDay == Container.shared.appModel().today }
  /// The day before and after the chosen one among the recorded days (newest first).
  var previousDay: WireDate? { neighbour(1) }
  var nextDay: WireDate? { neighbour(-1) }

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// Load the days list and the newest day, keeping the chosen day and symbol when still listed.
  func load(_ url: URL, preferring preferred: String?) async {
    let request = begin()
    phase = .loading
    do {
      let listed = try await client(url).days().days
      guard request == latestRequest else { return }
      days = listed
      if selectedDay == nil || !days.contains(where: { $0.day == selectedDay }) {
        selectedDay = days.first?.day
      }
      try await loadDay(url, preferring: preferred, request: request)
      if request == latestRequest { phase = .loaded }
    } catch is CancellationError {
      return
    } catch {
      if request == latestRequest { phase = .failed(ErrorText.text(error)) }
    }
  }

  /// Switch to another recorded day.
  func show(_ day: WireDate, from url: URL) async {
    let request = begin()
    selectedDay = day
    phase = .loading
    do {
      try await loadDay(url, preferring: symbol, request: request)
      if request == latestRequest { phase = .loaded }
    } catch is CancellationError {
      return
    } catch {
      if request == latestRequest { phase = .failed(ErrorText.text(error)) }
    }
  }

  /// Switch to another symbol of the chosen day.
  func show(symbol: String, from url: URL) async {
    self.symbol = symbol
    // Over a range the last symbol's candles and failure must not stay on screen while this one
    // loads: rebuild drops a GET /chart answer for another symbol.
    rangeFailure = nil
    rebuild()
    do {
      try await loadBars(url)
    } catch is CancellationError {
      return
    } catch {
      phase = .failed(ErrorText.text(error))
    }
  }

  /// Show the chart over `range`, keeping the interval when the range offers it, else its
  /// shortest. A range beyond one day waits for `loadRange`.
  func choose(range: ChartRange) {
    guard range != self.range else { return }
    self.range = range
    rangeChart = nil
    rangeWarmup = nil
    rangeFailure = nil
    if range.intervals.contains(timeframe) { rebuild() } else { timeframe = range.intervals.first ?? .m1 }
  }

  /// Read the chosen symbol's candles over the chosen range beyond one day (GET /chart). An
  /// answer for a symbol, range or interval no longer chosen is dropped.
  func loadRange(_ url: URL) async {
    guard range != .oneDay, let symbol else { return }
    let asked = (range, timeframe)
    do {
      let loaded = try await client(url).chart(symbol: symbol, interval: asked.1, range: asked.0)
      // The warm-up only shapes the lines' first values: without it the chart still shows.
      var warmup: ChartV1?
      if let longer = asked.0.warmup(for: asked.1) {
        warmup = try? await client(url).chart(symbol: symbol, interval: asked.1, range: longer)
      }
      guard symbol == self.symbol, asked == (range, timeframe) else { return }
      if loaded != rangeChart || warmup != rangeWarmup {
        rangeChart = loaded
        rangeWarmup = warmup
        rebuild()
      }
      rangeFailure = nil
    } catch is CancellationError {
      return
    } catch {
      guard symbol == self.symbol, asked == (range, timeframe) else { return }
      rangeFailure = ErrorText.text(error)
    }
  }

  /// Reload the chosen symbol's bars; used while today's chart is on screen. A failed reload
  /// keeps the candles already shown.
  func reloadBars(_ url: URL) async {
    try? await loadBars(url)
  }

  /// Starts a load of the days or a day; an answer to an older one is dropped, so a slow answer
  /// for a day no longer chosen never replaces the chosen day's trades, symbols or bars.
  private func begin() -> Int {
    latestRequest += 1
    return latestRequest
  }

  private func loadDay(_ url: URL, preferring preferred: String?, request: Int) async throws {
    guard let selectedDay else {
      day = nil
      bars = nil
      rebuild()
      return
    }
    let loaded = try await client(url).day(selectedDay)
    guard request == latestRequest else { return }
    day = loaded
    // The symbol asked for or already shown, else the first chip: an open position, else the
    // symbol traded last.
    let candidates = [preferred, symbol].compactMap { $0 }
    symbol = candidates.first(where: loaded.barSymbols.contains) ?? symbols.first
    try await loadBars(url)
  }

  private func loadBars(_ url: URL) async throws {
    guard let symbol, let selectedDay else {
      bars = nil
      clearDecisions()
      rebuild()
      return
    }
    // Another symbol or day: the last one's decisions must never show under this chart.
    if decisionsFor != DecisionsKey(symbol: symbol, day: selectedDay) { clearDecisions() }
    let loaded = try await client(url).bars(symbol: symbol, day: selectedDay)
    // A slower answer for a symbol or day no longer chosen is dropped.
    guard symbol == self.symbol, selectedDay == self.selectedDay else { return }
    bars = loaded
    rebuild()
    await loadDecisions(url, symbol: symbol, day: selectedDay)
  }

  private func clearDecisions() {
    decisions = nil
    decisionsFailure = nil
    decisionsFor = nil
  }

  /// The decisions behind the chart; a failure is shown on their card, never on the chart.
  private func loadDecisions(_ url: URL, symbol: String, day: WireDate) async {
    do {
      let loaded = try await client(url).decisions(symbol: symbol, day: day)
      guard symbol == self.symbol, day == selectedDay else { return }
      decisions = loaded
      decisionsFailure = nil
      decisionsFor = DecisionsKey(symbol: symbol, day: day)
    } catch is CancellationError {
      return
    } catch {
      guard symbol == self.symbol, day == selectedDay else { return }
      decisions = nil
      decisionsFailure = ErrorText.text(error)
      decisionsFor = DecisionsKey(symbol: symbol, day: day)
    }
  }

  private func rebuild() {
    if range == .oneDay {
      series = bars.map { ChartSeries(bars: $0.bars, timeframe: timeframe) }
      atr = bars.map { ChartSeries.atr(bars: $0.bars, timeframe: timeframe) } ?? []
      times = .day
      studies = CandleStudies(candles: series?.candles ?? [])
    } else if let rangeChart, rangeChart.symbol == symbol, rangeChart.range == range, rangeChart.interval == timeframe {
      let warm = WarmChart(chart: rangeChart, warmup: rangeWarmup)
      let drawn = warm.series.gapless()
      series = drawn
      atr = warm.atr
      studies = warm.studies
      times = ChartTimes(real: warm.series, drawn: drawn, range: range)
    } else {
      series = nil
      atr = []
      times = .day
      studies = CandleStudies(candles: [])
    }
  }

  private func neighbour(_ step: Int) -> WireDate? {
    guard let index = days.firstIndex(where: { $0.day == selectedDay }) else { return nil }
    let target = index + step
    return days.indices.contains(target) ? days[target].day : nil
  }
}

/// Real times of the drawn candles. On one day the candles keep their own clock and the axis
/// is automatic; beyond one day they sit back to back (no overnight, weekend or holiday gaps),
/// so the readout and the axis look their real times up here.
struct ChartTimes: Equatable {
  /// One day: the candles' own times.
  static let day = ChartTimes(range: .oneDay, timeframe: .m1, real: [:], marks: [])

  let range: ChartRange
  let timeframe: Timeframe
  /// Real opening time of each drawn candle, by its drawn start.
  let real: [Date: Date]
  /// Axis labels where a session, week, month or quarter begins, at drawn times.
  let marks: [ChartAxisLabel]

  private init(range: ChartRange, timeframe: Timeframe, real: [Date: Date], marks: [ChartAxisLabel]) {
    self.range = range
    self.timeframe = timeframe
    self.real = real
    self.marks = marks
  }

  /// `drawn` is `real.gapless()`: the same candles, index for index.
  init(real: ChartSeries, drawn: ChartSeries, range: ChartRange) {
    let starts = real.candles.map(\.start)
    self.range = range
    timeframe = real.timeframe
    self.real = Dictionary(zip(drawn.candles.map(\.start), starts), uniquingKeysWith: { first, _ in first })
    let labels = ChartAxis.labels(starts, range: range, timeframe: real.timeframe)
    marks = labels.indices
      .filter { drawn.candles.indices.contains($0) }
      .map { index in
        let start = starts[index]
        let january = WireDate.newYork.component(.month, from: start) == 1
        let yearStart = january && (labels.period == .month || labels.period == .quarter)
        return ChartAxisLabel(
          time: drawn.candles[index].start, text: Self.axisText(start, period: labels.period, range: range),
          major: yearStart)
      }
  }

  /// The candle's time in the readout and under the crosshair: "14:05" on one day, "Fri 13
  /// 14:05" over five days, "Fri, Nov 13" for a daily candle, the week's Monday for a weekly
  /// one, "Nov 2026" for a monthly one.
  func text(_ drawnStart: Date) -> String {
    let start = real[drawnStart] ?? drawnStart
    switch timeframe {
    case .d1: return start.formatted(ChartFormat.day)
    case .w1: return start.formatted(ChartFormat.monthDay)
    case .mo1: return start.formatted(ChartFormat.monthYear)
    default:
      let time = start.formatted(ChartFormat.time)
      return range == .oneDay ? time : [start.formatted(ChartFormat.sessionDay), time].joined(separator: ChartFormat.space)
    }
  }

  /// "Fri 13" for a session over five days, "Nov 9" for a week or a day of a longer range,
  /// "Nov" for a month or quarter ("2026" in January).
  private static func axisText(_ start: Date, period: ChartAxis.Period, range: ChartRange) -> String {
    switch period {
    case .day where range == .fiveDays: return start.formatted(ChartFormat.sessionDay)
    case .day, .week: return start.formatted(ChartFormat.monthDay)
    case .month, .quarter:
      let january = WireDate.newYork.component(.month, from: start) == 1
      return start.formatted(january ? ChartFormat.year : ChartFormat.month)
    }
  }

}

/// A labelled time on the axis beyond one day.
struct ChartAxisLabel: Equatable, Identifiable {
  let time: Date
  let text: String
  /// Where a year begins: kept over a month label it would collide with.
  var major = false
  var id: Date { time }
}
