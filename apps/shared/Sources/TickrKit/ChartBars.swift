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
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case symbol, interval, range, source, cause, bars
    case cachedAt = "cached_at"
    case apiVersion = "api_version"
    case causeCodes = "cause_codes"
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
    try c.encode(apiVersion, forKey: .apiVersion)
  }

  /// Why there are no candles, in the person's language (the bot's words for an unknown code).
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}
