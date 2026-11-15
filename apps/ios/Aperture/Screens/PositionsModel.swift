import ApertureKit
import Foundation
import Observation

/// Marks of the open positions for the Positions tab: each one's captured bars of the status's
/// session (GET /bars), read again every few seconds while the tab is on screen. Display only:
/// the bot never acts on them, and a failed read leaves a position without marks, never with
/// guessed ones.
@MainActor
@Observable
final class PositionsModel {
  /// Marks by symbol, for the positions whose bars could be read.
  private(set) var marks: [String: PositionMarks] = [:]

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// Read the bars of every position in `status` until cancelled.
  func follow(_ url: URL, status: StatusV1) async {
    while !Task.isCancelled {
      await load(url, status: status)
      try? await Task.sleep(for: .seconds(ChartModel.liveReloadSeconds))
    }
  }

  /// Read the bars of every position in `status` once.
  func load(_ url: URL, status: StatusV1) async {
    let day = WireDate(newYorkDateOf: status.writtenAt.date)
    var read: [String: PositionMarks] = [:]
    for position in status.positions {
      guard let bars = try? await client(url).bars(symbol: position.symbol, day: day) else { continue }
      read[position.symbol] = PositionMarks(bars: bars.bars, entry: position.entryPrice.value,
        stop: position.stop.price?.value, quantity: position.quantity.value, openedAt: position.openedAt.date)
    }
    guard !Task.isCancelled else { return }
    marks = read
  }
}
