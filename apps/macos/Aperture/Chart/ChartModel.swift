import ApertureKit
import Foundation
import Observation

/// Bars of the symbol the Chart screen shows, read from the bot's local API.
@MainActor @Observable
final class ChartModel {
  /// The last bars read for the shown symbol and day.
  private(set) var bars: BarsV1?
  /// Why the last read failed, if it did.
  private(set) var error: String?
  /// A read is in flight.
  private(set) var loading = false

  /// Reads the M1 bars of `symbol` on `day` from the API at `baseURL`. A cancelled read changes
  /// nothing.
  func load(baseURL: URL, symbol: String, day: WireDate) async {
    let client = Container.shared.apiClient(APIClient.Endpoint(baseURL: baseURL))
    loading = true
    defer { loading = false }
    do {
      let fresh = try await client.bars(symbol: symbol, day: day)
      guard !Task.isCancelled else { return }
      bars = fresh
      error = nil
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return }
      self.error = error.localizedDescription
    }
  }

  /// Forgets the shown bars when the symbol or day changes.
  func clear() {
    bars = nil
    error = nil
  }
}
