import ApertureKit
import Foundation
import Observation

/// Bars and strategy decisions of the symbol the Chart screen shows, read from the bot's local
/// API, or its candles over a longer range (GET /chart). The reads fail independently: a missing
/// decision list never hides the candles.
@MainActor @Observable
final class ChartModel {
  /// The last bars read for the shown symbol and day.
  private(set) var bars: BarsV1?
  /// The last candles read for the shown symbol over a range beyond one day.
  private(set) var rangeChart: ChartV1?
  /// A longer read in the same candles whose earlier candles warm the lines and studies up
  /// (`ChartRange.warmup`); nil when the range has none or that read failed.
  private(set) var rangeWarmup: ChartV1?
  /// Why the last read failed, if it did.
  private(set) var error: String?
  /// A read is in flight.
  private(set) var loading = false
  /// The last decisions read for the shown symbol and day.
  private(set) var decisions: DecisionsV1?
  /// Why the last decisions read failed, if it did.
  private(set) var decisionsError: String?
  /// The Chart shows a symbol; without one there are no decisions to ask the bot for.
  var hasSymbol = false
  /// Counts the reads that brought different bars; a plot built from an older count is stale.
  @ObservationIgnored private(set) var revision = 0
  /// The last plot built, reused while the bars and the timeframe stay the same.
  @ObservationIgnored private var cachedPlot: ChartPlot?

  /// Candles, lines and ATR of the shown day's bars in `timeframe`, or over `range` of the
  /// candles read from GET /chart; nil while there are none. Built once per new read, range or
  /// timeframe; every redraw in between reuses it.
  func plot(timeframe: Timeframe, range: ChartRange = .oneDay) -> ChartPlot? {
    if let cachedPlot, cachedPlot.revision == revision, cachedPlot.timeframe == timeframe, cachedPlot.range == range {
      return cachedPlot
    }
    let plot: ChartPlot
    if range == .oneDay {
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

  /// Whether the last read for `range` in `timeframe` has answered, with candles or without.
  func hasRead(timeframe: Timeframe, range: ChartRange) -> Bool {
    range == .oneDay ? bars != nil : rangeChart.map { $0.range == range && $0.interval == timeframe } ?? false
  }

  /// Why the read for a range beyond one day brought no candles, when the bot said.
  var rangeCause: String? { rangeChart?.cause }

  /// Reads the candles of `symbol` in `interval` over `range` (GET /chart). A cancelled read
  /// changes nothing; a refusal (503 while market data is off) shows its cause.
  func loadRange(baseURL: URL, symbol: String, interval: Timeframe, range: ChartRange) async {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL))
    loading = true
    defer { loading = false }
    do {
      let fresh = try await client.chart(symbol: symbol, interval: interval, range: range)
      // The warm-up only shapes the lines' first values: without it the chart still shows.
      var warmup: ChartV1?
      if let longer = range.warmup(for: interval) {
        warmup = try? await client.chart(symbol: symbol, interval: interval, range: longer)
      }
      guard !Task.isCancelled else { return }
      if fresh != rangeChart || warmup != rangeWarmup {
        rangeChart = fresh
        rangeWarmup = warmup
        revision += 1
      }
      error = nil
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return }
      self.error = ErrorText.text(error)
    }
  }

  /// Reads the M1 bars of `symbol` on `day` from the API at `baseURL`. A cancelled read changes
  /// nothing.
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
      self.error = ErrorText.text(error)
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
    rangeChart = nil
    rangeWarmup = nil
    revision += 1
    cachedPlot = nil
    error = nil
    decisions = nil
    decisionsError = nil
  }
}
