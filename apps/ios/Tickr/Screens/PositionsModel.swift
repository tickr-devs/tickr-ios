import Foundation
import Observation
import TickrDesign
import TickrKit

/// Marks of the open positions for the Positions tab: each one's bars of the status's session
/// where the Chart reads them too (`DayBars`: market data, else the capture), so both show one
/// price for one moment; read again every few seconds while the tab is on screen. The last price
/// and the results are the live bid of the bot's quotes (`LivePrice`) when there is one, so they
/// follow the market every second, not every captured bar. Display only: the bot never acts
/// on them, and a failed read leaves a position without marks, never with guessed ones.
@MainActor
@Observable
final class PositionsModel {
  /// Marks by symbol from the bars alone, for the positions whose bars could be read.
  private var barMarks: [String: PositionMarks] = [:]

  /// Marks by symbol, for the positions whose bars could be read, at the live bid where the bot's
  /// quotes have one (`AppModel.livePrice`).
  var marks: [String: PositionMarks] {
    let app = Container.shared.appModel()
    return barMarks.reduce(into: [:]) { found, entry in found[entry.key] = entry.value.live(app.livePrice(entry.key)) }
  }

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
      guard let bars = try? await DayBars.read(client(url), symbol: position.symbol, day: day, today: day) else {
        continue
      }
      read[position.symbol] = PositionMarks(bars: bars.bars, entry: position.entryPrice.value,
        stop: position.stop.price?.value, quantity: position.quantity.value, openedAt: position.openedAt.date)
    }
    guard !Task.isCancelled else { return }
    barMarks = read
  }
}

extension PositionMarks {
  /// The last price with its kind: "bid 12.34" when live, else "last 12.34" (a bar's close).
  var priceText: LocalizedStringResource {
    isLive ? L10n.Positions.bid(Money.price(last)) : L10n.Positions.last(Money.price(last))
  }
}
