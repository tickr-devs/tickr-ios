import Foundation

/// The facts beside the status headline (mockup v108): how long until the regular session opens
/// or closes, and whether the bot may enter. Pure, so both apps and the tests share them.

/// How long until the regular session opens or closes, from the bot's `/jobs`: inside today's
/// session the time to its close; otherwise the time to the next regular open (`next_session`,
/// from the same exchange calendar, so overnight, over weekends and holidays too), written as a
/// weekday and time once it is a day or more away ("Opens Mon 09:30"). Nil when neither is known
/// (the calendar could not answer, an older bot without `next_session` after today's close): nothing
/// is guessed.
public struct SessionCountdown: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    /// Before the next regular open, less than a day away: "Opens in 9 h 25 m".
    case opens
    /// A day or more before the next regular open: "Opens Mon 09:30".
    case opensOn
    /// Inside the regular session: "Closes in 42 m".
    case closes
  }

  public let kind: Kind
  /// Whole minutes left, rounded up: "1 m" until the very moment, never "0 m".
  public let minutes: Int
  /// The moment counted to: the open or the close.
  public let at: Date

  /// Seconds in a minute, minutes in an hour, and minutes in a day: from a day away the open is
  /// written as its weekday and time, not as a count of hours.
  static let secondsPerMinute: Double = 60
  static let minutesPerHour = 60
  static let minutesPerDay = 1440

  public init(kind: Kind, minutes: Int, at: Date) {
    self.kind = kind
    self.minutes = minutes
    self.at = at
  }

  /// The countdown at `now` (on the bot's clock) from today's `session` and the `next` regular
  /// session; nil when neither answers.
  public static func make(session: SessionTimesV1?, next: NextSessionV1?, now: Date) -> SessionCountdown? {
    if let session, now >= session.regularOpen.date, now < session.regularClose.date {
      let close = session.regularClose.date
      return SessionCountdown(kind: .closes, minutes: wholeMinutes(close.timeIntervalSince(now)), at: close)
    }
    // Today's open while it is still ahead, from an older bot that sends no `next_session`.
    let todayOpen = session.map(\.regularOpen.date).flatMap { $0 > now ? $0 : nil }
    guard let open = next.map(\.regularOpen.date) ?? todayOpen, open > now else { return nil }
    let minutes = wholeMinutes(open.timeIntervalSince(now))
    return SessionCountdown(kind: minutes >= minutesPerDay ? .opensOn : .opens, minutes: minutes, at: open)
  }

  private static func wholeMinutes(_ seconds: TimeInterval) -> Int {
    Int((seconds / secondsPerMinute).rounded(.up))
  }

  /// "Opens in", "Opens" or "Closes in", in the person's language.
  public var label: String {
    switch kind {
    case .opens: String(localized: L10n.countdownOpensIn)
    case .opensOn: String(localized: L10n.countdownOpensOn)
    case .closes: String(localized: L10n.countdownClosesIn)
    }
  }

  /// The time left, "9 h 25 m" or "42 m" under an hour; a day or more away, the open's weekday and
  /// New York time, "Mon 09:30".
  public func value(locale: Locale = .autoupdatingCurrent) -> String {
    if kind == .opensOn {
      var weekday = Date.FormatStyle.dateTime.weekday(.abbreviated).locale(locale)
      weekday.timeZone = WireDate.newYork.timeZone
      return String(localized: L10n.countdownWeekdayTime(at.formatted(weekday), ClockText.minutes(at)))
    }
    let hours = minutes / Self.minutesPerHour
    let rest = minutes % Self.minutesPerHour
    return String(localized: hours > 0 ? L10n.countdownHoursMinutes(hours, rest) : L10n.countdownMinutes(rest))
  }
}

/// Whether the bot may enter, as the badge beside the headline says it: the operator's entry stop
/// first (entries paused), then the trading gate (open or closed).
public enum EntryGate: Equatable, Sendable {
  case open, paused, closed

  /// The gate of `status`; nil without a status, and under an alarm headline, which takes the
  /// whole row and says what is wrong itself.
  public static func make(_ status: StatusV1?, headline: Headline) -> EntryGate? {
    guard let status, headline.severity != .alarm else { return nil }
    if status.entryStop { return .paused }
    return status.tradingGate.open ? .open : .closed
  }

  /// The badge's words.
  public var title: LocalizedStringResource {
    switch self {
    case .open: L10n.gateOpen
    case .paused: L10n.gatePaused
    case .closed: L10n.gateClosed
    }
  }
}
