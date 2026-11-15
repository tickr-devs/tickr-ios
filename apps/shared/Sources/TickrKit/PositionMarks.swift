import Foundation

/// Where an open position stands by the captured one-minute bars since it opened: the last price,
/// the open result, the result in R, and the worst and best prices reached (MAE and MFE). For
/// display only; the bot never acts on these, and the broker's numbers stay the truth.
public struct PositionMarks: Hashable, Sendable {
  /// Seconds in one captured bar (the API serves M1 only).
  public static let barSeconds: TimeInterval = 60

  /// Close of the newest bar.
  public let last: Decimal
  /// When the newest bar started.
  public let lastAt: Date
  /// (last − entry) × quantity, in dollars.
  public let unrealized: Decimal
  /// (last − entry) / (entry − stop); nil when the stop is unknown or not below the entry.
  public let resultR: Decimal?
  /// Lowest low − entry per share (zero or less): the most the position has been against us.
  public let adverse: Decimal
  /// Highest high − entry per share (zero or more): the most it has been for us.
  public let favorable: Decimal
  /// The same two in R, when R is defined.
  public let adverseR: Decimal?
  public let favorableR: Decimal?
  /// Closes since the open, oldest first, for the price line.
  public let closes: [Decimal]
  /// Lowest low and highest high since the open.
  public let low: Decimal
  public let high: Decimal

  /// Whether the newest bar is the latest one the bot can have captured by `now` (the bot's
  /// clock), give or take `staleSeconds`: a bar is captured once it closes, so the newest is up to
  /// one bar behind. Only then are the last price and the results current. Older marks are
  /// history and must say so.
  public func isFresh(now: Date, staleSeconds: TimeInterval) -> Bool {
    now.timeIntervalSince(lastAt.addingTimeInterval(Self.barSeconds)) <= Self.barSeconds + staleSeconds
  }

  /// Nil when no bar covers the time since the position opened.
  public init?(bars: [BarV1], entry: Decimal, stop: Decimal?, quantity: Decimal, openedAt: Date) {
    // The bar the fill happened in counts: it starts up to one bar before the open.
    let since = bars.filter { $0.start.date.addingTimeInterval(Self.barSeconds) > openedAt }
    guard let lastBar = since.last,
      let low = since.map(\.low.value).min(),
      let high = since.map(\.high.value).max() else { return nil }
    let risk: Decimal? = stop.flatMap { $0 < entry ? entry - $0 : nil }
    let last = lastBar.close.value
    let adverse = min(low - entry, 0)
    let favorable = max(high - entry, 0)
    self.last = last
    lastAt = lastBar.start.date
    unrealized = (last - entry) * quantity
    self.adverse = adverse
    self.favorable = favorable
    resultR = risk.map { (last - entry) / $0 }
    adverseR = risk.map { adverse / $0 }
    favorableR = risk.map { favorable / $0 }
    closes = since.map(\.close.value)
    self.low = low
    self.high = high
  }
}
