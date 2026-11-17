import Foundation

// Swift mirror of chart-v1 in src/tickr/api/contract.py: candles of any US stock from market
// data, in a chosen interval (`Timeframe`) over a chosen range (GET /chart).

/// How far back a chart-v1 read reaches.
public enum ChartRange: String, Codable, Sendable, CaseIterable {
  case oneDay = "1d"
  case fiveDays = "5d"
  case oneMonth = "1m"
  case threeMonths = "3m"
  case oneYear = "1y"

  /// Candle lengths the apps offer for this range, shortest first (the Chart boards of the
  /// design): pairs GET /chart serves, without those that give only a few candles (1M in
  /// monthly candles) or thousands (5D in M1 candles).
  public var intervals: [Timeframe] {
    switch self {
    case .oneDay: [.m1, .m5, .m30, .h1]
    case .fiveDays: [.m5, .m30, .h1]
    case .oneMonth: [.d1]
    case .threeMonths: [.d1, .w1]
    case .oneYear: [.d1, .w1, .mo1]
    }
  }

  /// The interval a range opens on when the one chosen before is not offered (mockup v113): Day
  /// shows its whole extended session in 5-minute candles, 5D in 30-minute ones; the longer
  /// ranges their shortest.
  public var openingInterval: Timeframe {
    switch self {
    case .oneDay: .m5
    case .fiveDays: .m30
    case .oneMonth, .threeMonths, .oneYear: intervals.first ?? .d1
    }
  }

  /// A longer range in the same candles whose earlier candles warm the lines and studies up,
  /// so they start at the left edge of this range (RSI 14 needs 14 candles before its first
  /// value); nil when there is none (the longest range, intraday candles).
  public func warmup(for interval: Timeframe) -> ChartRange? {
    switch self {
    case .oneMonth, .threeMonths: interval.isIntraday ? nil : .oneYear
    case .oneDay, .fiveDays, .oneYear: nil
    }
  }
}

/// The part of the day an intraday candle lies in, by the bot's session calendar.
public enum ChartSession: String, Codable, Hashable, Sendable {
  /// From the pre-market open (04:00 New York) to the regular open.
  case pre
  /// The regular session (09:30 to 16:00, or the half day's close).
  case regular
  /// From the regular close to the extended close (20:00, or 17:00 on a half day).
  case after
}

/// One candle; prices in USD, volume in shares.
public struct ChartBarV1: Codable, Hashable, Sendable {
  public let start: WireTime
  public let open: DecimalString
  public let high: DecimalString
  public let low: DecimalString
  public let close: DecimalString
  public let volume: DecimalString
  /// Whether the candle lies outside the regular session (pre-market or after hours).
  public let extended: Bool
  /// Which part of the day it lies in; nil for daily candles and from an API older than the key.
  public let session: ChartSession?

  enum CodingKeys: String, CodingKey {
    case start, open, high, low, close, volume, extended, session
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(start, forKey: .start)
    try c.encode(open, forKey: .open)
    try c.encode(high, forKey: .high)
    try c.encode(low, forKey: .low)
    try c.encode(close, forKey: .close)
    try c.encode(volume, forKey: .volume)
    try c.encode(extended, forKey: .extended)
    try c.encodeNullable(session, forKey: .session)
  }
}

/// What a chart answer still lacks because the chart's request budget ran out: `read` of `total`
/// parts are in `bars` (sessions for 1D and 5D, the newest ones; the one daily series, 0 of 1, for
/// the longer ranges), and the rest can be asked for after `retryAfterSeconds` (docs/api.md,
/// GET /chart, `pending`).
public struct ChartPendingV1: Codable, Hashable, Sendable {
  public let read: Int
  public let total: Int
  public let retryAfterSeconds: DecimalString

  enum CodingKeys: String, CodingKey {
    case read, total
    case retryAfterSeconds = "retry_after_seconds"
  }

  /// Seconds to wait before asking again.
  public var retryAfter: TimeInterval { NSDecimalNumber(decimal: retryAfterSeconds.value).doubleValue }
  /// Share of the parts read, 0...1.
  public var fraction: Double { total > 0 ? Double(read) / Double(total) : 0 }
}

/// Candles of `symbol`, oldest first; empty with `cause` when the source returned none.
public struct ChartV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let interval: Timeframe
  public let range: ChartRange
  /// Where the candles came from.
  public let source: String
  /// When the bot last fetched them; nil when it never did.
  public let cachedAt: WireTime?
  public let cause: String?
  /// The codes of `cause` (added after version 1 shipped: empty from an older API).
  public let causeCodes: [ReasonV1]
  public let bars: [ChartBarV1]
  /// Nil when the answer is complete; else what is still to come (added after version 1 shipped:
  /// nil from an older API).
  public let pending: ChartPendingV1?
  /// On a 1d range while its session runs, the after-hours candles the session before had in
  /// this interval: today's after-hours reserves as many slots (mockup v113). Nil otherwise
  /// (added after version 1 shipped).
  public let previousAfterCandles: Int?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case symbol, interval, range, source, cause, bars, pending
    case cachedAt = "cached_at"
    case apiVersion = "api_version"
    case causeCodes = "cause_codes"
    case previousAfterCandles = "previous_after_candles"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    symbol = try c.decode(String.self, forKey: .symbol)
    interval = try c.decode(Timeframe.self, forKey: .interval)
    range = try c.decode(ChartRange.self, forKey: .range)
    source = try c.decode(String.self, forKey: .source)
    cachedAt = try c.decodeNullable(WireTime.self, forKey: .cachedAt)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
    bars = try c.decode([ChartBarV1].self, forKey: .bars)
    pending = try c.decodeIfPresent(ChartPendingV1.self, forKey: .pending)
    previousAfterCandles = try c.decodeIfPresent(Int.self, forKey: .previousAfterCandles)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(interval, forKey: .interval)
    try c.encode(range, forKey: .range)
    try c.encode(source, forKey: .source)
    try c.encodeNullable(cachedAt, forKey: .cachedAt)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
    try c.encode(bars, forKey: .bars)
    try c.encodeNullable(pending, forKey: .pending)
    try c.encodeNullable(previousAfterCandles, forKey: .previousAfterCandles)
    try c.encode(apiVersion, forKey: .apiVersion)
  }

  /// Why there are no candles, in the person's language (the bot's words for an unknown code).
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}

public extension ChartV1 {
  /// Whether this Day answer holds the session of New York date `day`: GET /chart's 1d range is
  /// the latest session whose pre-market has begun, which before 04:00 is the day before. A
  /// pending answer with no candles yet counts: its session is still being read.
  func holdsSession(of day: WireDate) -> Bool {
    guard range == .oneDay else { return false }
    guard let first = bars.first else { return pending != nil }
    return WireDate(newYorkDateOf: first.start.date) == day
  }
}
