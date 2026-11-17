import Foundation
import Observation
import TickrDesign
import TickrKit

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
  /// The chosen past day, the app's one shown day (`AppModel.selectedDay`); nil while today is
  /// shown.
  var selectedDay: WireDate? { Container.shared.appModel().selectedDay }
  /// The chosen past day's trades, once loaded.
  private(set) var day: DayV1?
  /// The record of the status's session (GET /days/<date>), for what the status leaves out.
  private(set) var session: DayV1?
  /// The active strategy's skipped entries of the shown day (GET /skipped), repeats grouped,
  /// newest first once read; `skippedDay` is the day they are of.
  private(set) var skipped: [SkippedGroup]?
  private(set) var skippedDay: WireDate?
  /// Why the skipped entries could not be read, if they could not.
  private(set) var skippedFailure: String?
  /// The shown day's journal (GET /events) as lines, newest first, once read; `journalDay` is
  /// the day they are of. Nil until read, and when the bot cannot serve it (an older bot: today
  /// then shows what the status says).
  private(set) var journal: [Board.Event]?
  private(set) var journalDay: WireDate?
  /// The month the calendar shows.
  var month = DayCalendar.Month(Container.shared.appModel().today)
  /// Number of the newest load of a day; an answer to an older one is dropped.
  @ObservationIgnored private var latestRequest = 0
  /// The past day this tab last began reading; another tab's pick is read when it differs.
  @ObservationIgnored private var askedDay: WireDate?
  /// Number of the newest load of the days list, likewise.
  @ObservationIgnored private var latestDaysRequest = 0
  /// The bot's address `session` was read from.
  @ObservationIgnored private var sessionSource: URL?
  /// The bot's address the days were listed from; another address starts again from today.
  @ObservationIgnored private var source: URL?
  /// What was read of the past days shown last: a day picked again shows at once, then is read
  /// again behind it (`PastDays`, as on the Mac).
  @ObservationIgnored private var pastDays = PastDays<ActivityDayParts>()

  /// Today in New York, on the bot's clock.
  var today: WireDate { Container.shared.appModel().today }
  /// The months the calendar can show, newest first.
  var months: [DayCalendar.Month] { DayCalendar.months(days, including: today) }
  /// The shown month as weeks of Monday to Friday.
  var weeks: [[DayCalendar.Cell?]] { DayCalendar.weeks(of: month, days: days) }
  /// The month before and after the shown one among `months`.
  var previousMonth: DayCalendar.Month? { months.first { $0 < month } }
  var nextMonth: DayCalendar.Month? { months.last { $0 > month } }
  /// The bot's summary of the chosen past day.
  var summary: DaySummary? { days.first { $0.day == selectedDay } }

  /// The API's error for a request it declines for now (GET /trades/whatif in the session).
  static let declinedForNow = "conflict"

  /// The bot's API at `url`, from the container, with the paired token only where it may go.
  private func client(_ url: URL) -> APIClient {
    Container.shared.apiClient(Container.shared.appModel().connection.endpoint(for: url))
  }

  /// The strategy versions the bot can replay on a closed trade (from GET /lab/replay), ones that
  /// do not trade first.
  func replayableVersions(_ url: URL) async -> Result<[LabVersionV1], WhatIfFailure> {
    do {
      let all = try await client(url).labReplay().versions.filter { $0.cause == nil }
      return .success(all.filter { $0.role != .active } + all.filter { $0.role == .active })
    } catch {
      return .failure(WhatIfFailure(cause: ErrorText.text(error)))
    }
  }

  /// What strategy folder `version` would have done on `symbol`'s `day` (GET /trades/whatif,
  /// simulated). A refusal (the session is open) or a failed read is its reason as sent.
  func whatIf(_ url: URL, symbol: String, day: WireDate, version: String) async -> Result<TradeWhatIfV1, WhatIfFailure> {
    do {
      return .success(try await client(url).tradeWhatIf(symbol: symbol, day: day, version: version))
    } catch APIError.refused(_, let error, let cause) {
      // `conflict`: declined for now (the session is open); any other refusal is a failure.
      return .failure(WhatIfFailure(cause: cause, refused: error == Self.declinedForNow))
    } catch {
      return .failure(WhatIfFailure(cause: ErrorText.text(error)))
    }
  }

  /// List the recorded days for the calendar.
  /// A different address than before drops the past day chosen on the other Mac.
  func loadDays(_ url: URL) async {
    if url != source {
      source = url
      days = []
      pastDays = PastDays()
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
      if request == latestDaysRequest { daysFailure = ErrorText.text(error) }
    }
  }

  /// The New York date of the session `status` describes.
  func sessionDay(of status: StatusV1) -> WireDate {
    WireDate(newYorkDateOf: status.writtenAt.date)
  }

  /// Read the record of `status`'s session. A failed read leaves the rows without MAE and MFE; nothing
  /// else depends on it.
  func loadSession(_ url: URL, of status: StatusV1) async {
    let day = sessionDay(of: status)
    // Another bot's or another day's record never lends its MAE and MFE to these rows.
    if url != sessionSource || session?.day != day { session = nil }
    sessionSource = url
    guard let loaded = try? await client(url).day(day), loaded.day == day else { return }
    session = loaded
  }

  /// Read the skipped entries of `day`. Another day's list is never shown under this one.
  func loadSkipped(_ url: URL, day: WireDate) async {
    if skippedDay != day {
      skipped = pastDays.parts(of: day)?.skipped
      skippedFailure = nil
      skippedDay = day
    }
    do {
      let read = try await client(url).skipped(day: day)
      guard read.day == day, day == skippedDay else { return }
      let groups = SkippedGroup.make(read.signals)
      skipped = groups
      skippedFailure = nil
      pastDays.keep(day, today: today, empty: ActivityDayParts()) { $0.skipped = groups }
    } catch is CancellationError {
      return
    } catch {
      if day == skippedDay { skippedFailure = ErrorText.text(error) }
    }
  }

  /// Read the journal of `day`. Another day's lines are never shown under this one.
  func loadJournal(_ url: URL, day: WireDate) async {
    if journalDay != day {
      journal = pastDays.parts(of: day)?.journal
      journalDay = day
    }
    guard let read = try? await client(url).events(day: day), read.day == day, day == journalDay else { return }
    let lines = Board.journal(read, price: Money.price)
    journal = lines
    pastDays.keep(day, today: today, empty: ActivityDayParts()) { $0.journal = lines }
  }

  /// Show `day`: today goes back to the live view, any other recorded day loads its trades. With
  /// the demo day on, only the demo day (today) is shown.
  func show(_ day: WireDate, from url: URL) async {
    guard day != today, DemoDay.day(day, demo: Container.shared.appModel().connection.demo) != nil else {
      showToday()
      return
    }
    let request = begin()
    askedDay = day
    Container.shared.appModel().selectedDay = day
    month = DayCalendar.Month(day)
    // A day read before shows at once; it is read again behind it.
    self.day = pastDays.parts(of: day)?.day
    phase = self.day == nil ? .loading : .loaded
    do {
      let loaded = try await client(url).day(day)
      guard request == latestRequest else { return }
      phase = Self.phase(of: loaded, asked: day)
      self.day = phase == .loaded ? loaded : nil
      if phase == .loaded { pastDays.keep(day, today: today, empty: ActivityDayParts()) { $0.day = loaded } }
    } catch {
      // A cancelled load (a refresh cut short by leaving the tab) fails too, so the day offers
      // a retry instead of a spinner that never ends.
      if request == latestRequest { phase = .failed(ErrorText.text(error)) }
    }
  }

  /// What a read of `asked` that answered `loaded` shows: its trades, or, for another day's
  /// document, the refusal; another day's trades are never shown under the picked one.
  static func phase(of loaded: DayV1, asked: WireDate) -> Phase {
    loaded.day == asked ? .loaded : .failed(String(localized: L10n.Activity.otherDayAnswered(asked.text, loaded.day.text)))
  }

  /// Back to today, live from the status.
  func showToday() {
    _ = begin()
    askedDay = nil
    Container.shared.appModel().selectedDay = nil
    day = nil
    phase = .idle
    month = DayCalendar.Month(today)
  }

  /// Follows the app's shown day when another tab changed it (Home's arrows, the Chart's day
  /// menu): reads that day's trades, or goes back to today.
  func follow(from url: URL) async {
    if let picked = selectedDay {
      guard picked != askedDay else { return }  // read (or being read) here already
      await show(picked, from: url)
    } else if phase != .idle {
      showToday()
    }
  }

  private func begin() -> Int {
    latestRequest += 1
    return latestRequest
  }
}

/// What the phone read of one past day (`ActivityModel.pastDays`); a part not read yet is nil.
struct ActivityDayParts: Sendable {
  var day: DayV1?
  var skipped: [SkippedGroup]?
  var journal: [Board.Event]?
}

/// Why a what-if of another version could not be shown: the bot's refusal or a failed read, as
/// sent.
struct WhatIfFailure: Error, Equatable {
  let cause: String
  /// The API answered and declined (the regular session is open: "Available after 16:00 ET"):
  /// a state to explain, not a failed read.
  var refused = false
}
