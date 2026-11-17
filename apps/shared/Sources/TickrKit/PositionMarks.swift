import Foundation

/// Where an open position stands by the captured one-minute bars since it opened: the last price,
/// the open result, the result in R, and the worst and best prices reached (MAE and MFE). For
/// display only; the bot never acts on these, and the broker's numbers stay the truth.
public struct PositionMarks: Hashable, Sendable {
  /// Seconds in one captured bar (the API serves M1 only).
  public static let barSeconds: TimeInterval = 60

  /// Close of the newest bar, or the live bid once `live(_:)` gave one.
  public let last: Decimal
  /// When the newest bar started, or when the live bid was quoted.
  public let lastAt: Date
  /// `last` is the live bid of the bot's quote stream, not a bar's close.
  public let isLive: Bool
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
  /// The price line since the fill, oldest first: the entry price, then the close of every bar
  /// since the open. It starts at the fill, so one bar already draws a line.
  public let closes: [Decimal]
  /// Lowest low and highest high since the open.
  public let low: Decimal
  public let high: Decimal

  /// Whether the newest bar is the latest one the bot can have captured by `now` (the bot's
  /// clock), give or take `staleSeconds`: a bar is captured once it closes, so the newest is up to
  /// one bar behind. Only then are the last price and the results current. Older marks are
  /// history and must say so. Live marks are always current.
  public func isFresh(now: Date, staleSeconds: TimeInterval) -> Bool {
    isLive || now.timeIntervalSince(lastAt.addingTimeInterval(Self.barSeconds)) <= Self.barSeconds + staleSeconds
  }

  /// Nil when no bar covers the time since the position opened.
  public init?(bars: [BarV1], entry: Decimal, stop: Decimal?, quantity: Decimal, openedAt: Date) {
    // The bar the fill happened in counts: it starts up to one bar before the open.
    let since = bars.filter { $0.start.date.addingTimeInterval(Self.barSeconds) > openedAt }
    guard let lastBar = since.last,
      let low = since.map(\.low.value).min(),
      let high = since.map(\.high.value).max() else { return nil }
    self.init(newest: Newest(price: lastBar.close.value, at: lastBar.start.date, isLive: false),
      path: Path(low: low, high: high, closes: [entry] + since.map(\.close.value)),
      basis: Basis(entry: entry, stop: stop, quantity: quantity))
  }

  /// These marks with the position's live bid as the last price, when there is one: the result,
  /// R and the extremes follow it at once, and the line ends at it. Unchanged without one.
  public func live(_ price: LivePrice?) -> PositionMarks {
    guard let price else { return self }
    return PositionMarks(newest: Newest(price: price.bid, at: price.quotedAt, isLive: true),
      path: Path(low: min(low, price.bid), high: max(high, price.bid), closes: closes + [price.bid]), basis: basis)
  }

  /// The newest price, when it was, and whether it is the live bid.
  private struct Newest {
    let price: Decimal
    let at: Date
    let isLive: Bool
  }

  /// The extremes and the price line since the open.
  private struct Path {
    let low: Decimal
    let high: Decimal
    let closes: [Decimal]
  }

  /// What the results are measured from.
  private struct Basis: Hashable, Sendable {
    let entry: Decimal
    let stop: Decimal?
    let quantity: Decimal
  }

  private let basis: Basis

  private init(newest: Newest, path: Path, basis: Basis) {
    let entry = basis.entry
    let last = newest.price
    let risk: Decimal? = basis.stop.flatMap { $0 < entry ? entry - $0 : nil }
    let adverse = min(path.low - entry, 0)
    let favorable = max(path.high - entry, 0)
    self.last = last
    lastAt = newest.at
    isLive = newest.isLive
    unrealized = (last - entry) * basis.quantity
    self.adverse = adverse
    self.favorable = favorable
    resultR = risk.map { (last - entry) / $0 }
    adverseR = risk.map { adverse / $0 }
    favorableR = risk.map { favorable / $0 }
    closes = path.closes
    low = path.low
    high = path.high
    self.basis = basis
  }
}
