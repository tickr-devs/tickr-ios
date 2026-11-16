import Foundation

/// The day a session strip draws, on both apps (Settings › Session): from the pre-market open to
/// the extended close, with the regular session and the bot's cutoffs inside. Every time comes
/// from the bot's `/jobs` session, which reads the exchange calendar (half days included).
public struct SessionSpan: Hashable, Sendable {
  /// Where the strip starts and ends: the calendar's `premarket_open` and `extended_close`.
  public let start: Date
  public let end: Date
  public let regularOpen: Date
  public let lastEntry: Date
  public let flatten: Date
  public let regularClose: Date
  /// Whether `start` and `end` are the calendar's own (false only for an older bot's session).
  public let extendedHoursKnown: Bool

  /// How long a full day's extended sessions run around the regular one, in hours (pre-market from
  /// 04:00, post-market to 20:00 New York): only for a session from a bot older than
  /// `premarket_open` and `extended_close` (docs/api.md, GET /jobs).
  static let olderBotPreMarketHours: Double = 5.5
  static let olderBotPostMarketHours: Double = 4
  /// Seconds in an hour, and in a minute.
  static let secondsPerHour: Double = 3600
  static let secondsPerMinute: Double = 60

  public init(_ session: SessionTimesV1) {
    regularOpen = session.regularOpen.date
    lastEntry = session.lastEntryAt.date
    flatten = session.flattenAt.date
    regularClose = session.regularClose.date
    start = session.premarketOpen?.date
      ?? regularOpen.addingTimeInterval(-Self.olderBotPreMarketHours * Self.secondsPerHour)
    end = session.extendedClose?.date
      ?? regularClose.addingTimeInterval(Self.olderBotPostMarketHours * Self.secondsPerHour)
    extendedHoursKnown = session.premarketOpen != nil && session.extendedClose != nil
  }

  /// Where `date` falls on the strip, from 0 at its start to 1 at its end.
  public func share(_ date: Date) -> Double {
    date.timeIntervalSince(start) / end.timeIntervalSince(start)
  }

  /// Whether `date` is inside the strip (a now line is drawn).
  public func contains(_ date: Date) -> Bool { date > start && date < end }

  /// The part of the day `date` is in.
  public enum Part: Hashable, Sendable { case closed, preMarket, regular, afterHours }

  public func part(at date: Date) -> Part {
    if date >= start && date < regularOpen { return .preMarket }
    if date >= regularOpen && date < regularClose { return .regular }
    if date >= regularClose && date < end { return .afterHours }
    return .closed
  }

  /// How many of the day's marks (pre-market open, open, last entry, flatten, close, extended
  /// close) `date` has reached: it changes only when now passes one (one pulse per change).
  public func marksPassed(at date: Date) -> Int {
    [start, regularOpen, lastEntry, flatten, regularClose, end].filter { date >= $0 }.count
  }

  /// `date` to its whole minute: a now line moves once a minute.
  public static func minute(_ date: Date) -> Date {
    Date(timeIntervalSinceReferenceDate:
      (date.timeIntervalSinceReferenceDate / secondsPerMinute).rounded(.down) * secondsPerMinute)
  }
}
