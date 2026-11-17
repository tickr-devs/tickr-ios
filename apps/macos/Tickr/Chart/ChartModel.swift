import Foundation
import Observation
import TickrKit

/// Candles and strategy decisions of the symbol the Chart screen shows, read from the bot's local
/// API: today's session and the longer ranges from market data (GET /chart, every session), a
/// recorded day from the bot's capture (GET /bars). The reads fail independently: a missing
/// decision list never hides the candles.
@MainActor @Observable
final class ChartModel {
  /// The last bars read for the shown symbol and a recorded day (the bot's capture).
  private(set) var bars: BarsV1?
  /// Today's session of the shown symbol from market data (GET /chart, 1d): pre-market, regular
  /// session and after-hours.
  private(set) var dayChart: ChartV1?
  /// The last candles read for the shown symbol over a range beyond one day.
  private(set) var rangeChart: ChartV1?
  /// A longer read in the same candles whose earlier candles warm the lines and studies up
  /// (`ChartRange.warmup`); nil when the range has none or that read failed.
  private(set) var rangeWarmup: ChartV1?
  /// Why the last read failed, if it did: a refusal's cause alone, in the person's language.
  private(set) var error: String?
  /// A read is in flight.
  private(set) var loading = false
  /// The last decisions read for the shown symbol and day.
  private(set) var decisions: DecisionsV1?
  /// Why the last decisions read failed, if it did.
  private(set) var decisionsError: String?
  /// The Chart shows a symbol; without one there are no decisions to ask the bot for.
  var hasSymbol = false
  /// The symbol, range and interval the chart shows, for the title bar's line; nil until a
  /// symbol has something to show.
  var shown: Shown?
  /// Counts the reads that brought different bars; a plot built from an older count is stale.
  @ObservationIgnored private(set) var revision = 0
  /// The last plot built, reused while the bars and the timeframe stay the same.
  @ObservationIgnored private var cachedPlot: ChartPlot?

  /// Candles, lines and ATR of the shown day's bars in `timeframe`, or over `range` of the
  /// candles read from GET /chart; nil while there are none. Built once per new read, range or
  /// timeframe; every redraw in between reuses it.
  func plot(timeframe: Timeframe, range: ChartRange = .oneDay, today: SessionSpan? = nil) -> ChartPlot? {
    if let cachedPlot, cachedPlot.revision == revision, cachedPlot.timeframe == timeframe, cachedPlot.range == range,
      cachedPlot.today == (range == .oneDay && dayChart != nil ? today : nil) {
      return cachedPlot
    }
    let plot: ChartPlot
    if range == .oneDay, let dayChart {
      guard dayChart.interval == timeframe, !dayChart.bars.isEmpty else { return nil }
      plot = ChartPlot(chart: dayChart, today: today, revision: revision)
    } else if range == .oneDay {
      guard let bars, !bars.bars.isEmpty else { return nil }
      plot = ChartPlot(bars: bars.bars, timeframe: timeframe, revision: revision)
    } else {
      guard let rangeChart, rangeChart.range == range, rangeChart.interval == timeframe, !rangeChart.bars.isEmpty else {
        return nil
      }
      plot = ChartPlot(chart: rangeChart, warmup: rangeWarmup, revision: revision)
    }
    cachedPlot = plot
    return plot
  }

  /// What the shown chart still waits for while the chart's request budget fills it (a cold 5D
  /// reads one session per request): nil when it is complete.
  var pending: ChartPendingV1? { dayChart?.pending ?? rangeChart?.pending }

  /// Start of the newest candle read for the shown day: a change is a new candle, the one event
  /// the LIVE pill's dot pulses for (not each read, which brings the same candle most of the time).
  var newestBar: WireTime? { dayChart?.bars.last?.start ?? bars?.bars.last?.start }

  /// Whether the last read for `range` in `timeframe` has answered, with candles or without.
  func hasRead(timeframe: Timeframe, range: ChartRange) -> Bool {
    range == .oneDay
      ? bars != nil || dayChart?.interval == timeframe
      : rangeChart.map { $0.range == range && $0.interval == timeframe } ?? false
  }

  /// Why the read for a range beyond one day brought no candles, when the bot said.
  var rangeCause: String? { rangeChart?.causeText }

  /// Reads the candles of `symbol` in `interval` over `range` (GET /chart). A cancelled read
  /// changes nothing; a refusal (503 while market data is off) shows its cause. Returns how long
  /// to wait before asking again while the answer is `pending` (the chart's budget fills it).
  @discardableResult
  func loadRange(baseURL: URL, symbol: String, interval: Timeframe, range: ChartRange) async -> TimeInterval? {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL))
    loading = true
    defer { loading = false }
    do {
      let fresh = try await client.chart(symbol: symbol, interval: interval, range: range)
      // The warm-up only shapes the lines' first values: without it the chart still shows. Not
      // asked while the range itself still fills: the budget goes to its missing days first.
      var warmup: ChartV1?
      if fresh.pending == nil, let longer = range.warmup(for: interval) {
        warmup = try? await client.chart(symbol: symbol, interval: interval, range: longer)
      }
      guard !Task.isCancelled else { return nil }
      if fresh != rangeChart || warmup != rangeWarmup {
        rangeChart = fresh
        rangeWarmup = warmup
        revision += 1
      }
      error = nil
      return fresh.pending?.retryAfter
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return nil }
      self.error = ErrorText.cause(error)
      return nil
    }
  }

  /// Reads today's session of `symbol` in `interval` from market data (GET /chart, 1d): every
  /// session, as the longer ranges. While market data is unavailable (503: the chart is off or
  /// not ready) or the latest session is not `day` yet (before its 04:00 pre-market), the bot's
  /// capture is read instead (`load`), so today's chart still shows what the bot recorded.
  /// Returns how long to wait before asking again while the answer is `pending`.
  @discardableResult
  func loadToday(baseURL: URL, symbol: String, interval: Timeframe, day: WireDate) async -> TimeInterval? {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL))
    loading = true
    defer { loading = false }
    do {
      let fresh = try await client.chart(symbol: symbol, interval: interval, range: .oneDay)
      guard !Task.isCancelled else { return nil }
      guard fresh.holdsSession(of: day) else {
        await useCapture(baseURL: baseURL, symbol: symbol, day: day)
        return nil
      }
      if fresh != dayChart {
        dayChart = fresh
        bars = nil
        revision += 1
      }
      error = nil
      return fresh.pending?.retryAfter
    } catch APIError.refused(let status, _, _) where status == Self.unavailable {
      await useCapture(baseURL: baseURL, symbol: symbol, day: day)
      return nil
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return nil }
      self.error = ErrorText.cause(error)
      return nil
    }
  }

  /// HTTP status of GET /chart while market data is off or not ready (docs/api.md).
  static let unavailable = 503

  private func useCapture(baseURL: URL, symbol: String, day: WireDate) async {
    if dayChart != nil {
      dayChart = nil
      revision += 1
    }
    await load(baseURL: baseURL, symbol: symbol, day: day)
  }

  /// Reads the M1 bars of `symbol` on `day` from the API at `baseURL` (the bot's capture). A
  /// cancelled read changes nothing.
  func load(baseURL: URL, symbol: String, day: WireDate) async {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL))
    loading = true
    defer { loading = false }
    do {
      let fresh = try await client.bars(symbol: symbol, day: day)
      guard !Task.isCancelled else { return }
      // A live chart reads every few seconds; unchanged bars must not redraw it.
      if fresh != bars {
        bars = fresh
        revision += 1
      }
      error = nil
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return }
      self.error = ErrorText.cause(error)
    }
  }

  /// Reads the strategy decisions on `symbol` on `day`. A failed read clears the earlier answer,
  /// so the inspector never shows an old list as current; a cancelled read changes nothing.
  func loadDecisions(baseURL: URL, symbol: String, day: WireDate) async {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL))
    do {
      let fresh = try await client.decisions(symbol: symbol, day: day)
      guard !Task.isCancelled else { return }
      if fresh != decisions { decisions = fresh }
      decisionsError = nil
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return }
      decisions = nil
      decisionsError = ErrorText.text(error)
    }
  }

  /// Forgets the shown bars, candles and decisions when the symbol, day or range changes.
  func clear() {
    bars = nil
    dayChart = nil
    rangeChart = nil
    rangeWarmup = nil
    revision += 1
    cachedPlot = nil
    error = nil
    decisions = nil
    decisionsError = nil
    shown = nil
  }

  /// What the chart shows: a symbol over a range in candles of an interval.
  struct Shown: Equatable {
    let symbol: String
    let range: ChartRange
    let interval: Timeframe
  }
}
