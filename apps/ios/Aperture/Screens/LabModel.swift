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
  /// The active strategy's refused signals of `refusalsDay` by cause (GET /skipped), once read.
  private(set) var refusals: [RefusalCount]?
  private(set) var refusalsDay: WireDate?
  /// Why they could not be read, if they could not.
  private(set) var refusalsFailure: String?
  /// The bot everything above came from.
  @ObservationIgnored private var source: URL?

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// Read the observers and the refusals of `day` from the bot at `url`; another bot's answers are
  /// dropped first.
  func load(_ url: URL, day: WireDate) async {
    if source != url {
      observers = nil
      failure = nil
      refusals = nil
      refusalsDay = nil
      refusalsFailure = nil
      source = url
    }
    await loadObservers(url, day: day)
    await loadRefusals(url, day: day)
  }

  /// Read the refused signals of `day`. Another day's counts are never shown under this one.
  func loadRefusals(_ url: URL, day: WireDate) async {
    if refusalsDay != day {
      refusals = nil
      refusalsFailure = nil
      refusalsDay = day
    }
    do {
      let read = try await client(url).skipped(day: day)
      guard read.day == day, day == refusalsDay else { return }
      refusals = RefusalCount.make(read.signals)
      refusalsFailure = nil
    } catch is CancellationError {
      return
    } catch {
      if day == refusalsDay { refusalsFailure = error.localizedDescription }
    }
  }

  /// Read the observers of `day`. Another day's answer is never shown under this one.
  func loadObservers(_ url: URL, day: WireDate) async {
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
