import Foundation

// Swift mirror of chart-v1 in src/aperture/api/contract.py: candles of any US stock from market
// data, in a chosen interval over a chosen range (GET /chart).

/// Candle length of a chart-v1 read.
public enum ChartInterval: String, Codable, Sendable, CaseIterable {
  case oneMinute = "1m"
  case fiveMinutes = "5m"
  case thirtyMinutes = "30m"
  case oneHour = "1h"
  case oneDay = "1d"
  case oneWeek = "1w"
  case oneMonth = "1mo"
}

/// How far back a chart-v1 read reaches.
public enum ChartRange: String, Codable, Sendable, CaseIterable {
  case oneDay = "1d"
  case fiveDays = "5d"
  case oneMonth = "1m"
  case threeMonths = "3m"
  case oneYear = "1y"
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
  public let interval: ChartInterval
  public let range: ChartRange
  /// Where the candles came from.
  public let source: String
  /// When the bot last fetched them; nil when it never did.
  public let cachedAt: WireTime?
  public let cause: String?
  public let bars: [ChartBarV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case symbol, interval, range, source, cause, bars
    case cachedAt = "cached_at"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    symbol = try c.decode(String.self, forKey: .symbol)
    interval = try c.decode(ChartInterval.self, forKey: .interval)
    range = try c.decode(ChartRange.self, forKey: .range)
    source = try c.decode(String.self, forKey: .source)
    cachedAt = try c.decodeNullable(WireTime.self, forKey: .cachedAt)
    cause = try c.decodeNullable(String.self, forKey: .cause)
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
    try c.encode(bars, forKey: .bars)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
