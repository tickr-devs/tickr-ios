import Foundation
import Observation
import TickrKit

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

  /// Seconds between reloads of today's bars while the chart is on screen, when they come from
  /// the bot's capture. The bot captures one bar a minute, so a few reloads a minute keep the
  /// last candle current.
  static let liveReloadSeconds = 15.0
  /// Seconds between reads of market data (GET /chart: today's session and five sessions): the
  /// bot keeps them a while and the chart has its own small request budget.
  static let rangeReloadSeconds = 60.0

  private(set) var phase = Phase.idle
  private(set) var days: [DaySummary] = []
  private(set) var day: DayV1?
  private(set) var bars: BarsV1?
  /// Today's session of the chosen symbol from market data (GET /chart, 1d): pre-market, regular
  /// session and after-hours; nil on a recorded day (its bars are the bot's capture).
  private(set) var dayChart: ChartV1?
  var selectedDay: WireDate?
  var symbol: String?
  var timeframe = ChartRange.oneDay.openingInterval { didSet { rebuild() } }
  /// How far back the chart reaches: the chosen day's recorded bars, or market data over several
  /// sessions or months (GET /chart). Change it with `choose(range:)`.
  private(set) var range = ChartRange.oneDay
  /// The last candles read from GET /chart for the chosen symbol, range and interval.
  private(set) var rangeChart: ChartV1?
  /// A longer read in the same candles whose earlier candles warm the lines up
  /// (`ChartRange.warmup`); nil when the range has none or that read failed.
  private(set) var rangeWarmup: ChartV1?
  /// Why the last GET /chart read failed, if it did (a 503 while market data is off): the
  /// refusal's cause alone, in the person's language.
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
  /// Where the trading strategy began watching and said enter on the chosen symbol's candles,
  /// found in their real candles and drawn on the same candles back to back.
  var events: [ChartEvent] {
    guard range == .oneDay, let series, let decisions = shownDecisions else { return [] }
    return ChartEvent.make(decisions.decisions, candles: times.realCandles, drawn: series.candles)
  }

  /// What the shown chart still waits for while the chart's request budget fills it: nil when
  /// it is complete.
  var pending: ChartPendingV1? { range == .oneDay ? dayChart?.pending : rangeChart?.pending }

  /// Seconds until today's chart is read again: when the bot says while its budget fills it, at
  /// the market data's pace, else at the capture's.
  var todayReloadSeconds: TimeInterval {
    dayChart?.pending?.retryAfter ?? (dayChart != nil ? Self.rangeReloadSeconds : Self.liveReloadSeconds)
  }

  /// Today's session from the calendar (GET /jobs) on today's chart: the Day chart keeps the rest
  /// of the day to the extended close (mockup v113).
  var todaySession: SessionSpan? {
    guard isToday, let session = Container.shared.appModel().jobs?.session, session.day == selectedDay else {
      return nil
    }
    return SessionSpan(session)
  }
  /// Trades of the chosen symbol closed on the chosen day.
  var trades: [DayTrade] { day?.trades.filter { $0.symbol == symbol } ?? [] }
  /// Whether the chosen day is today in New York on the bot's clock, so its bars still grow.
  var isToday: Bool { selectedDay == Container.shared.appModel().today }

  /// The symbol's live bid (GET /quotes) while today is shown; nil otherwise or without a live
  /// quote, and then the last closed candle stands for the price.
  var livePrice: Double? {
    guard isToday, let symbol, let live = Container.shared.appModel().livePrice(symbol) else { return nil }
    return NSDecimalNumber(decimal: live.bid).doubleValue
  }
  /// The chosen symbol's previous close while today is shown (`DayChange`); nil otherwise or when
  /// no screener listed it today.
  var previousClose: Decimal? {
    guard isToday, let symbol else { return nil }
    return DayChange.previousClose(symbol, flow: Container.shared.appModel().flow)
  }
  /// The day before and after the chosen one among the recorded days (newest first); none while
  /// the demo day is on, the only day then.
  var previousDay: WireDate? { dayLocked ? nil : neighbour(1) }
  var nextDay: WireDate? { dayLocked ? nil : neighbour(-1) }
  /// The demo day is on: the chart stays on its day (the API's today).
  var dayLocked: Bool { Container.shared.appModel().connection.demo }

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
      if dayLocked {
        // The demo day is the newest the demo has recorded.
        selectedDay = days.first?.day
      } else if selectedDay == nil || !days.contains(where: { $0.day == selectedDay }) {
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

  /// Switch to another recorded day; none while the demo day is on.
  func show(_ day: WireDate, from url: URL) async {
    guard !dayLocked else { return }
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

  /// Show the chart over `range` in the interval it opens on. A range beyond one day waits for
  /// `loadRange`.
  func choose(range: ChartRange) {
    guard range != self.range else { return }
    self.range = range
    rangeChart = nil
    rangeWarmup = nil
    rangeFailure = nil
    // Mockup v113: a range opens on its own interval (Day 5m, 5D 30m).
    if timeframe == range.openingInterval { rebuild() } else { timeframe = range.openingInterval }
  }

  /// Read the chosen symbol's candles over the chosen range beyond one day (GET /chart). An
  /// answer for a symbol, range or interval no longer chosen is dropped.
  /// Returns how long to wait before asking again while the answer is `pending` (the chart's
  /// budget fills a cold 5D one session per request).
  @discardableResult
  func loadRange(_ url: URL) async -> TimeInterval? {
    guard range != .oneDay, let symbol else { return nil }
    let asked = (range, timeframe)
    do {
      let loaded = try await client(url).chart(symbol: symbol, interval: asked.1, range: asked.0)
      // The warm-up only shapes the lines' first values: without it the chart still shows. Not
      // asked while the range itself still fills: the budget goes to its missing days first.
      var warmup: ChartV1?
      if loaded.pending == nil, let longer = asked.0.warmup(for: asked.1) {
        warmup = try? await client(url).chart(symbol: symbol, interval: asked.1, range: longer)
      }
      guard symbol == self.symbol, asked == (range, timeframe) else { return nil }
      if loaded != rangeChart || warmup != rangeWarmup {
        rangeChart = loaded
        rangeWarmup = warmup
        rebuild()
      }
      rangeFailure = nil
      return loaded.pending?.retryAfter
    } catch is CancellationError {
      return nil
    } catch {
      guard symbol == self.symbol, asked == (range, timeframe) else { return nil }
      rangeFailure = ErrorText.cause(error)
      return nil
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
    let asked = timeframe
    // Where every screen reads a day's bars (`DayBars`): today from market data in the chosen
    // interval, else (a recorded day, or no market data) the bot's capture.
    let read = try await DayBars.read(
      client(url), symbol: symbol, day: selectedDay, today: Container.shared.appModel().today, interval: asked)
    // A slower answer for a symbol, day or interval no longer chosen is dropped.
    guard symbol == self.symbol, selectedDay == self.selectedDay, asked == timeframe else { return }
    switch read {
    case .marketData(let chart):
      dayChart = chart
      bars = nil
    case .capture(let captured):
      dayChart = nil
      bars = captured
    }
    rebuild()
    await loadDecisions(url, symbol: symbol, day: selectedDay)
  }

  /// Whether today's market data was read in another interval than the chosen one: read again.
  var needsTodayRead: Bool { dayChart.map { $0.interval != timeframe } ?? false }

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
      // Today from market data in the chosen interval, else the recorded day's capture.
      let real: ChartSeries?
      var warm: WarmChart?
      if let dayChart {
        warm = dayChart.interval == timeframe ? WarmChart(chart: dayChart, warmup: nil) : nil
        real = warm?.series
      } else {
        real = bars.map { ChartSeries(bars: $0.bars, timeframe: timeframe) }
      }
      guard let real else {
        clearSeries()
        return
      }
      let drawn = real.gapless()
      series = drawn
      atr = warm?.atr ?? bars.map { ChartSeries.atr(bars: $0.bars, timeframe: timeframe) } ?? []
      studies = warm?.studies ?? CandleStudies(candles: real.candles)
      times = ChartTimes(real: real, drawn: drawn, range: .oneDay, today: dayChart != nil ? todaySession : nil,
        afterSlots: dayChart?.previousAfterCandles)
    } else if let rangeChart, rangeChart.symbol == symbol, rangeChart.range == range, rangeChart.interval == timeframe {
      let warm = WarmChart(chart: rangeChart, warmup: rangeWarmup)
      let drawn = warm.series.gapless()
      series = drawn
      atr = warm.atr
      studies = warm.studies
      times = ChartTimes(real: warm.series, drawn: drawn, range: range)
    } else {
      clearSeries()
    }
  }

  private func clearSeries() {
    series = nil
    atr = []
    times = .day
    studies = CandleStudies(candles: [])
  }

  private func neighbour(_ step: Int) -> WireDate? {
    guard let index = days.firstIndex(where: { $0.day == selectedDay }) else { return nil }
    let target = index + step
    return days.indices.contains(target) ? days[target].day : nil
  }
}

/// Real times of the drawn candles, which sit back to back on every range (no overnight,
/// weekend or holiday gap, no hole for a minute without trades; mockup v113), so the readout, the
/// axis and the marks look their real times up here.
struct ChartTimes: Equatable {
  /// Nothing drawn yet.
  static let day = ChartTimes(range: .oneDay, timeframe: .m1, real: [:], marks: [])

  let range: ChartRange
  let timeframe: Timeframe
  /// Real opening time of each drawn candle, by its drawn start.
  let real: [Date: Date]
  /// The candles at their real times, index for index with the drawn ones.
  let realCandles: [Candle]
  /// Where a real time (a trade, the position's entry) is drawn.
  let clock: GaplessClock
  /// Day and 5D: the parts of the day (bands, boundaries, the time axis), with the rest of today
  /// reserved on today's Day chart; nil for daily, weekly and monthly candles.
  let sessions: SessionAxis?
  /// The extended close a Day axis ends on: today's from the calendar, else the last candle's end.
  let extendedClose: Date?
  /// Drawn start of the first candle.
  let origin: Date?
  /// Axis labels where a week, month or quarter begins, at drawn times (a month or longer).
  let marks: [ChartAxisLabel]

  private init(range: ChartRange, timeframe: Timeframe, real: [Date: Date], marks: [ChartAxisLabel]) {
    self.range = range
    self.timeframe = timeframe
    self.real = real
    self.marks = marks
    realCandles = []
    clock = GaplessClock(candles: [], length: timeframe.seconds)
    sessions = nil
    extendedClose = nil
    origin = nil
  }

  /// `drawn` is `real.gapless()`: the same candles, index for index. `today`: the calendar's
  /// session on today's Day chart, whose rest is reserved (`SessionAxis`), the after-hours as
  /// `afterSlots` slots when the bot said how many the session before had.
  init(real: ChartSeries, drawn: ChartSeries, range: ChartRange, today: SessionSpan? = nil, afterSlots: Int? = nil) {
    let starts = real.candles.map(\.start)
    self.range = range
    timeframe = real.timeframe
    self.real = Dictionary(zip(drawn.candles.map(\.start), starts), uniquingKeysWith: { first, _ in first })
    realCandles = real.candles
    clock = GaplessClock(real: real)
    origin = drawn.candles.first?.start
    let intraday = real.timeframe.isIntraday
    sessions = intraday
      ? SessionAxis(candles: real.candles, timeframe: real.timeframe, today: today, afterSlots: afterSlots) : nil
    extendedClose = intraday ? (today?.end ?? real.candles.last?.end) : nil
    guard !intraday else {
      marks = []
      return
    }
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

  /// Where a real time is drawn; nil before the first candle.
  func drawn(_ time: Date) -> Date? { clock.drawn(time) }

  /// The drawn start of slot `slot`: a candle's, or a reserved one's after the last candle.
  func slotTime(_ slot: Int) -> Date? {
    origin.map { $0.addingTimeInterval(Double(slot) * timeframe.seconds) }
  }

  /// Where the drawn time axis ends, after today's reserved slots; nil without them.
  var reservedEnd: Date? {
    guard let sessions, sessions.slots > sessions.candleSlots else { return nil }
    return slotTime(sessions.slots)
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
      let text = range == .oneDay ? time : [start.formatted(ChartFormat.sessionDay), time].joined(separator: ChartFormat.space)
      // "19:50 · after" (mockup v113).
      let part: LocalizedStringResource? =
        switch realCandles.first(where: { $0.start == start })?.session {
        case .pre: ChartSessionWords.preShort
        case .after: ChartSessionWords.afterShort
        case .regular, nil: nil
        }
      return part.map { [text, String(localized: $0)].joined(separator: ChartFormat.separator) } ?? text
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

/// A labelled time on the time axis.
struct ChartAxisLabel: Equatable, Identifiable {
  let time: Date
  let text: String
  /// Where a year begins: kept over a month label it would collide with.
  var major = false
  /// A session, its end or a day's name on a Day or 5D axis, drawn stronger than a round time.
  var strong = false
  /// How a session axis's label hangs from its time; nil: inward near either end.
  var anchor: ChartAxis.Anchor?
  /// How far a session axis's label sits from where Charts hangs it, in points.
  var offset: CGFloat = 0
  var id: Date { time }
}
