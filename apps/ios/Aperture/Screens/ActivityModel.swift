import ApertureKit
import Foundation
import Observation

/// Which day the Activity tab shows: today, live from the status, or a recorded past day read from
/// the bot's API (GET /days for the calendar, GET /days/<date> for the day's trades). Read-only
/// history; the phone never computes anything the bot acts on.
@MainActor
@Observable
final class ActivityModel {
  enum Phase: Equatable {
    case idle
    case loading
    case failed(String)
    case loaded
  }

  /// State of the chosen past day's load.
  private(set) var phase = Phase.idle
  /// Every recorded day, newest first.
  private(set) var days: [DaySummary] = []
  /// Why the recorded days could not be listed, if they could not.
  private(set) var daysFailure: String?
  /// The chosen past day; nil while today is shown.
  private(set) var selectedDay: WireDate?
  /// The chosen past day's trades, once loaded.
  private(set) var day: DayV1?
  /// The month the calendar shows.
  var month = DayCalendar.Month(WireDate(newYorkDateOf: .now))
  /// Number of the newest load of a day; an answer to an older one is dropped.
  @ObservationIgnored private var latestRequest = 0
  /// Number of the newest load of the days list, likewise.
  @ObservationIgnored private var latestDaysRequest = 0
  /// The bot's address the days were listed from; another address starts again from today.
  @ObservationIgnored private var source: URL?

  /// Today in New York.
  var today: WireDate { WireDate(newYorkDateOf: .now) }
  /// The months the calendar can show, newest first.
  var months: [DayCalendar.Month] { DayCalendar.months(days, including: today) }
  /// The shown month as weeks of Monday to Friday.
  var weeks: [[DayCalendar.Cell?]] { DayCalendar.weeks(of: month, days: days) }
  /// The month before and after the shown one among `months`.
  var previousMonth: DayCalendar.Month? { months.first { $0 < month } }
  var nextMonth: DayCalendar.Month? { months.last { $0 > month } }
  /// The bot's summary of the chosen past day.
  var summary: DaySummary? { days.first { $0.day == selectedDay } }

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// List the recorded days for the calendar.
  /// A different address than before drops the past day chosen on the other Mac.
  func loadDays(_ url: URL) async {
    if url != source {
      source = url
      days = []
      showToday()
    }
    latestDaysRequest += 1
    let request = latestDaysRequest
    do {
      let listed = try await client(url).days().days
      guard request == latestDaysRequest else { return }
      days = listed
      daysFailure = nil
    } catch is CancellationError {
      return
    } catch {
      if request == latestDaysRequest { daysFailure = error.localizedDescription }
    }
  }

  /// Show `day`: today goes back to the live view, any other recorded day loads its trades.
  func show(_ day: WireDate, from url: URL) async {
    guard day != today else {
      showToday()
      return
    }
    let request = begin()
    selectedDay = day
    self.day = nil
    phase = .loading
    do {
      let loaded = try await client(url).day(day)
      guard request == latestRequest else { return }
      self.day = loaded
      phase = .loaded
    } catch {
      // A cancelled load (a refresh cut short by leaving the tab) fails too, so the day offers
      // a retry instead of a spinner that never ends.
      if request == latestRequest { phase = .failed(error.localizedDescription) }
    }
  }

  /// Back to today, live from the status.
  func showToday() {
    _ = begin()
    selectedDay = nil
    day = nil
    phase = .idle
    month = DayCalendar.Month(today)
  }

  private func begin() -> Int {
    latestRequest += 1
    return latestRequest
  }
}
