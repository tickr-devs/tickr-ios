import ApertureKit
import Foundation
import Observation

/// Which day Home shows: today, live from the status, or a recorded past day stepped to with the
/// day switcher, summarized from GET /days. A past day is read-only; nothing live is shown for it.
@MainActor
@Observable
final class HomeDayModel {
  /// Every recorded day, newest first, once listed.
  private(set) var days: [DaySummary] = []
  /// The chosen past day; nil while today is shown.
  private(set) var shown: DaySummary?
  /// The bot the days were listed from; another bot starts again from today.
  @ObservationIgnored private var source: URL?
  @ObservationIgnored @Injected(\.appModel) private var app

  /// Today in New York, on the bot's clock.
  private var today: WireDate { app.today }

  /// The day the switcher stands on: the chosen past day, else today.
  var day: WireDate { shown?.day ?? today }
  var canGoBack: Bool { DaySteps.previous(day, in: days) != nil }
  var canGoForward: Bool { shown != nil }

  /// List the recorded days of the bot at `url`. A failed list leaves the switcher where it was;
  /// it only offers fewer steps.
  func load(_ url: URL) async {
    if source != url {
      source = url
      days = []
      shown = nil
    }
    let client = Container.shared.apiClient(app.connection.endpoint(for: url))
    guard let listed = try? await client.days().days, source == url else { return }
    days = listed
    // A day no longer listed (another environment's database) is not shown as recorded.
    if let shown, !listed.contains(where: { $0.day == shown.day }) { self.shown = nil }
  }

  func back() {
    if let previous = DaySteps.previous(day, in: days) { shown = previous }
  }

  /// One day forward; from the newest past day, back to today.
  func forward() {
    guard shown != nil else { return }
    shown = DaySteps.next(day, in: days, today: today)
  }

  func showToday() { shown = nil }
}
