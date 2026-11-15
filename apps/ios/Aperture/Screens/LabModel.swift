import ApertureKit
import Foundation
import Observation

/// The Lab's observers: what each shadow strategy decided on the status's session (GET
/// /observers), read when the tab opens and on refresh. Read-only; observers never trade.
@MainActor
@Observable
final class LabModel {
  /// The observers of `day`, once read.
  private(set) var observers: ObserversV1?
  /// Why they could not be read, if they could not.
  private(set) var failure: String?

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// Read the observers of `day`. Another day's answer is never shown under this one.
  func load(_ url: URL, day: WireDate) async {
    if observers?.day != day { observers = nil }
    do {
      let read = try await client(url).observers(day: day)
      guard read.day == day else { return }
      observers = read
      failure = nil
    } catch is CancellationError {
      return
    } catch {
      failure = error.localizedDescription
    }
  }
}
