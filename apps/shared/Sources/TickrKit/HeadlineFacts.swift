import Foundation

/// The facts beside the status headline (mockup v108): how long until the regular session opens
/// or closes, and whether the bot may enter. Pure, so both apps and the tests share them.

/// How long until today's regular session opens or closes, from the bot's `/jobs` session, which
/// reads the exchange calendar (half days included). Nil outside both: after the close, and on a
/// day without a session, the next open is not in that data, so nothing is guessed.
public struct SessionCountdown: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    /// Before the regular open (the night and the pre-market).
    case opens
    /// Inside the regular session.
    case closes
  }

  public let kind: Kind
  /// Whole minutes left, rounded up: "1 m" until the very moment, never "0 m".
  public let minutes: Int

  /// Seconds in a minute, and minutes in an hour.
  static let secondsPerMinute: Double = 60
  static let minutesPerHour = 60

  public init(kind: Kind, minutes: Int) {
    self.kind = kind
    self.minutes = minutes
  }

  /// The countdown at `now` (on the bot's clock) for `session`; nil without one or after its close.
  public static func make(session: SessionTimesV1?, now: Date) -> SessionCountdown? {
    guard let session else { return nil }
    let open = session.regularOpen.date
    let close = session.regularClose.date
    if now < open { return SessionCountdown(kind: .opens, minutes: wholeMinutes(open.timeIntervalSince(now))) }
    if now < close { return SessionCountdown(kind: .closes, minutes: wholeMinutes(close.timeIntervalSince(now))) }
    return nil
  }

  private static func wholeMinutes(_ seconds: TimeInterval) -> Int {
    Int((seconds / secondsPerMinute).rounded(.up))
  }

  /// "Opens in" or "Closes in", in the person's language.
  public var label: String {
    String(localized: kind == .opens ? L10n.countdownOpensIn : L10n.countdownClosesIn)
  }

  /// The time left: "9 h 25 m", or "42 m" under an hour.
  public var value: String {
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
