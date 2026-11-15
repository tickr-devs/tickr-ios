import ApertureKit
import Foundation
import Observation

/// The symbols the strategy is watching closely today (GET /watching), read again every few
/// seconds while the Positions tab is on screen. Read-only; a failed read keeps the last rows and
/// says why.
@MainActor
@Observable
final class WatchingModel {
  /// The rows of `day`, once read.
  private(set) var watching: WatchingV1?
  /// Why the rows could not be read, if they could not.
  private(set) var failure: String?

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// Read the rows of `day` until cancelled.
  func follow(_ url: URL, day: WireDate) async {
    while !Task.isCancelled {
      await load(url, day: day)
      try? await Task.sleep(for: .seconds(ChartModel.liveReloadSeconds))
    }
  }

  /// Read the rows of `day` once. Another day's rows are never shown under this one.
  func load(_ url: URL, day: WireDate) async {
    if watching?.day != day {
      watching = nil
      failure = nil
    }
    do {
      let read = try await client(url).watching(day: day)
      guard read.day == day else { return }
      watching = read
      failure = nil
    } catch is CancellationError {
      return
    } catch {
      failure = error.localizedDescription
    }
  }
}
