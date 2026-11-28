import Foundation
import Observation
import TickrKit

/// Home's day switcher over the recorded days (GET /days). The day it steps to is the app's one
/// shown day (`AppModel.selectedDay`), so every tab follows it. A past day is read-only; nothing
/// live is shown for it.
@MainActor
@Observable
final class HomeDayModel {
  /// Every recorded day, newest first, once listed.
  private(set) var days: [DaySummary] = []
  /// The shown past day's summary; nil while today is shown (or the day is not listed yet).
  var shown: DaySummary? { app.selectedDay.flatMap { day in days.first { $0.day == day } } }
  /// The bot the days were listed from; another bot starts again from today.
  @ObservationIgnored private var source: URL?
  @ObservationIgnored @Injected(\.appModel) private var app

  /// The day the live page stands for (`DaySteps.liveDay`).
  private var liveDay: WireDate { DaySteps.liveDay(today: app.today, lastStatus: app.status?.writtenAt.date) }

  /// The day the switcher stands on: the chosen past day, else the live page's day.
  var day: WireDate { app.selectedDay ?? liveDay }
  /// The switcher stands still: the demo day is the only day while its switch is on.
  var locked: Bool { app.connection.demo }
  var canGoBack: Bool { !locked && DaySteps.previous(day, in: days) != nil }
  var canGoForward: Bool { app.selectedDay != nil }
  /// The day switch's steps (`DaySwitch`, `daySwipe`): none while the day is locked or no other
  /// day is recorded, the one that leads nowhere disabled.
  var arrows: DayArrows { DayArrows(locked: locked, canGoBack: canGoBack, canGoForward: canGoForward) }

  /// List the recorded days of the bot at `url`. A failed list leaves the switcher where it was;
  /// it only offers fewer steps.
  func load(_ url: URL) async {
    if source != url {
      source = url
      days = []
    }
    let client = Container.shared.apiClient(app.connection.endpoint(for: url))
    guard let listed = try? await client.days().days, source == url else { return }
    days = listed
    // A day no longer listed (another environment's database) is not shown as recorded.
    if let picked = app.selectedDay, !listed.contains(where: { $0.day == picked }) { app.selectedDay = nil }
  }

  func back() {
    guard !locked else { return }
    if let previous = DaySteps.previous(day, in: days) { app.selectedDay = previous.day }
  }

  /// One day forward; from the newest past day, back to today.
  func forward() {
    guard app.selectedDay != nil else { return }
    app.selectedDay = DaySteps.next(day, in: days, today: liveDay)?.day
  }

  func showToday() { app.selectedDay = nil }
}
