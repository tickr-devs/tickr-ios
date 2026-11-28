import Foundation

/// Whether the bot is meant to be running now, by its trading calendar (GET /status `schedule`),
/// and what its silence means (owner-approved 2026-11-28, mockup v190, page p-off): off by the
/// schedule is calm ("Bot is off until Mon 04:00 ET"); red only when the bot should be running and
/// is silent. Pure, so both apps and the tests share it.
///
/// Nil leaves the screens as they were, alarmed by a stale status: the schedule is unknown (an
/// older API, or the calendar cannot say, `scheduleCause`), or the last status shows a position or
/// a working entry order, which the schedule must never hide (Fable, review of tickr-bot#20), or
/// there is no status at all, so what the bot holds is unknown.
public enum BotRun: Equatable, Sendable {
  /// Off by the schedule until `start`; its run ends at `end`. `weekend`: today is a Saturday or
  /// Sunday in New York.
  case off(start: Date, end: Date, weekend: Bool)
  /// Off by the schedule, its start less than `soonMinutes` away.
  case startingSoon(start: Date, end: Date)
  /// Meant to run since `start`, which is less than the status stale limit ago: the bot has not
  /// had the time any status gets to be written (Fable: decide from the status age around the
  /// start minute, never from `expected_running` alone).
  case starting(start: Date)
  /// Meant to run and its status is fresh: nothing to add. Also a fresh status off the schedule
  /// (started by hand): it is running, whatever the calendar says.
  case running
  /// Meant to run since `start` (nil when the API does not say) and silent past the stale limit.
  case silent(start: Date?)

  /// Minutes before the start from which "Bot starts in N min" replaces "off until" (the p-off
  /// board's "less than 15 min to 04:00 ET").
  public static let soonMinutes = 15
  static let secondsPerMinute: TimeInterval = 60

  /// The run state at `now` (the bot's clock), the status counting as silent `staleSeconds` after
  /// a run's start (the bot's `status_stale_seconds`); `runStartedAt` the run's start when the API
  /// sends it.
  public static func make(response: StatusResponseV1?, staleSeconds: TimeInterval?, runStartedAt: Date?, now: Date)
    -> BotRun? {
    // No status (missing or unreadable file): what the bot holds is unknown, so no calm.
    guard let response, let schedule = response.schedule, let status = response.status else { return nil }
    if !status.positions.isEmpty || !status.workingEntries.isEmpty { return nil }
    if !response.stale { return .running }
    guard schedule.expectedRunning else {
      let start = schedule.nextStartAt.date
      let end = schedule.nextEndAt.date
      // A start already past with the schedule still saying off: the schedule is behind, never calm.
      if start <= now { return .silent(start: start) }
      if start.timeIntervalSince(now) < Double(soonMinutes) * secondsPerMinute { return .startingSoon(start: start, end: end) }
      return .off(start: start, end: end, weekend: WireDate.newYork.isDateInWeekend(now))
    }
    if let runStartedAt, let staleSeconds, now.timeIntervalSince(runStartedAt) < staleSeconds {
      return .starting(start: runStartedAt)
    }
    return .silent(start: runStartedAt)
  }

  /// Whether the bot's silence is expected: off, about to start or starting. The screens then stay
  /// calm (no red, no "no answer"); a silent run or an unknown schedule keeps the alarm.
  public var calm: Bool {
    switch self {
    case .off, .startingSoon, .starting: true
    case .running, .silent: false
    }
  }
}

extension BotRun {
  /// The headline of a calm or silent run; nil while it runs (the status's own headline then).
  /// `lastAnswer`: when the last status was written.
  public func headline(lastAnswer: Date?, now: Date) -> Headline? {
    switch self {
    case let .off(start, _, weekend):
      return Headline(text: String(localized: L10n.botOffUntil(Self.weekdayTime(start))), severity: .ok, calm: true,
        detail: String(localized: weekend ? L10n.botOffWeekend : L10n.botOffStartsByItself))
    case let .startingSoon(start, _):
      let minutes = max(1, Int((start.timeIntervalSince(now) / Self.secondsPerMinute).rounded(.up)))
      return Headline(text: String(localized: L10n.botStartsIn(minutes)), severity: .ok, calm: true,
        pulse: .text(String(localized: L10n.botStarting)),
        detail: String(localized: L10n.botPremarketOpens(ClockText.minutes(start))))
    case let .starting(start):
      return Headline(text: String(localized: L10n.botStarting), severity: .ok, calm: true,
        detail: String(localized: L10n.botPremarketOpens(ClockText.minutes(start))))
    case let .silent(start):
      let last = lastAnswer.map(ClockText.minutes) ?? ApiText.missing
      let detail = start.map { L10n.botShouldRunSince(ClockText.minutes($0), last) } ?? L10n.botShouldRun(last)
      return Headline(text: String(localized: L10n.botNotAnswering), severity: .alarm, pulse: .stale,
        detail: String(localized: detail))
    case .running:
      return nil
    }
  }

  /// The sidebar's short state while calm ("Off · until Mon 04:00"); nil otherwise.
  public var shortText: String? {
    switch self {
    case let .off(start, _, _), let .startingSoon(start, _):
      String(localized: L10n.botOffShort(Self.weekdayTime(start)))
    case .starting:
      String(localized: L10n.botStarting)
    case .running, .silent:
      nil
    }
  }

  /// "Mon 04:00": the abbreviated weekday and New York time, as the session countdown writes a day
  /// away.
  static func weekdayTime(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    var weekday = Date.FormatStyle.dateTime.weekday(.abbreviated).locale(locale)
    weekday.timeZone = WireDate.newYork.timeZone
    return String(localized: L10n.countdownWeekdayTime(date.formatted(weekday), ClockText.minutes(date)))
  }
}
