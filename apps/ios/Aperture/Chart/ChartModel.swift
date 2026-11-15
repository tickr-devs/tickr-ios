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

  private(set) var phase = Phase.idle
  private(set) var days: [DaySummary] = []
  private(set) var day: DayV1?
  private(set) var bars: BarsV1?
  var selectedDay: WireDate?
  var symbol: String?
  var timeframe = Timeframe.m1 { didSet { rebuild() } }
  private(set) var series: ChartSeries?
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
    guard let series, let decisions = shownDecisions else { return [] }
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
      if request == latestRequest { phase = .failed(error.localizedDescription) }
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
      if request == latestRequest { phase = .failed(error.localizedDescription) }
    }
  }

  /// Switch to another symbol of the chosen day.
  func show(symbol: String, from url: URL) async {
    self.symbol = symbol
    do {
      try await loadBars(url)
    } catch is CancellationError {
      return
    } catch {
      phase = .failed(error.localizedDescription)
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
      decisionsFailure = error.localizedDescription
      decisionsFor = DecisionsKey(symbol: symbol, day: day)
    }
  }

  private func rebuild() {
    series = bars.map { ChartSeries(bars: $0.bars, timeframe: timeframe) }
    atr = bars.map { ChartSeries.atr(bars: $0.bars, timeframe: timeframe) } ?? []
    studies = CandleStudies(candles: series?.candles ?? [])
  }

  private func neighbour(_ step: Int) -> WireDate? {
    guard let index = days.firstIndex(where: { $0.day == selectedDay }) else { return nil }
    let target = index + step
    return days.indices.contains(target) ? days[target].day : nil
  }
}
