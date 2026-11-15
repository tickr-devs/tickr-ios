import ApertureKit
import Foundation
import Observation

/// Bars and strategy decisions of the symbol the Chart screen shows, read from the bot's local
/// API. The two reads fail independently: a missing decision list never hides the candles.
@MainActor @Observable
final class ChartModel {
  /// The last bars read for the shown symbol and day.
  private(set) var bars: BarsV1?
  /// Why the last read failed, if it did.
  private(set) var error: String?
  /// A read is in flight.
  private(set) var loading = false
  /// The last decisions read for the shown symbol and day.
  private(set) var decisions: DecisionsV1?
  /// Why the last decisions read failed, if it did.
  private(set) var decisionsError: String?
  /// Counts the reads that brought different bars; a plot built from an older count is stale.
  @ObservationIgnored private(set) var revision = 0
  /// The last plot built, reused while the bars and the timeframe stay the same.
  @ObservationIgnored private var cachedPlot: ChartPlot?

  /// Candles, lines and ATR of the shown bars in `timeframe`, or nil while there are no bars.
  /// Built once per new bars or timeframe; every redraw in between reuses it.
  func plot(timeframe: Timeframe) -> ChartPlot? {
    guard let bars, !bars.bars.isEmpty else { return nil }
    if let cachedPlot, cachedPlot.revision == revision, cachedPlot.timeframe == timeframe { return cachedPlot }
    let plot = ChartPlot(bars: bars.bars, timeframe: timeframe, revision: revision)
    cachedPlot = plot
    return plot
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
      self.error = error.localizedDescription
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
      decisionsError = error.localizedDescription
    }
  }

  /// Forgets the shown bars and decisions when the symbol or day changes.
  func clear() {
    bars = nil
    revision += 1
    cachedPlot = nil
    error = nil
    decisions = nil
    decisionsError = nil
  }
}
