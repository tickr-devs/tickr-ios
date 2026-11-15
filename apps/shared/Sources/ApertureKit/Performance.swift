import Foundation

// Swift mirror of performance-v1 in src/aperture/api/contract.py: gross results in R over a range
// of New York days. 1 R is a trade's planned loss.

/// A figure the bot computes when it can, or the cause it could not (exactly one is non-nil).
public struct CausedDecimal: Hashable, Sendable {
  public let value: DecimalString?
  public let cause: String?
}

/// Trades left out of every figure, grouped by why.
public struct PerformanceExclusionV1: Codable, Hashable, Sendable {
  public let cause: String
  public let trades: Int
}

/// One day of the range that has closed trades.
public struct PerformanceDayV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let trades: Int
  public let resultGrossR: DecimalString
  public let resultGrossUsd: DecimalString
  /// Running sum of `resultGrossR` from the first day of the range.
  public let cumulativeGrossR: DecimalString

  enum CodingKeys: String, CodingKey {
    case day, trades
    case resultGrossR = "result_gross_r"
    case resultGrossUsd = "result_gross_usd"
    case cumulativeGrossR = "cumulative_gross_r"
  }
}

/// Performance of the trades closed from `fromDay` to `toDay`, both inclusive; every figure gross.
public struct PerformanceV1: Codable, Hashable, Sendable {
  public let environment: String
  public let fromDay: WireDate
  public let toDay: WireDate
  public let trades: Int
  public let wins: Int
  public let losses: Int
  public let scratches: Int
  public let exclusions: [PerformanceExclusionV1]
  /// Share of wins among the counted trades, 0 to 1.
  public let winRate: CausedDecimal
  public let expectancyGrossR: CausedDecimal
  public let expectancyGrossUsd: CausedDecimal
  public let averageWinGrossR: CausedDecimal
  public let averageLossGrossR: CausedDecimal
  /// Gross profit over gross loss, in USD.
  public let profitFactorGross: CausedDecimal
  /// Deepest fall from a running peak that starts at 0, positive.
  public let maxDrawdownGrossR: DecimalString
  public let maxDrawdownGrossUsd: DecimalString
  public let resultGrossR: DecimalString
  public let resultGrossUsd: DecimalString
  /// Days with closed trades, oldest first.
  public let days: [PerformanceDayV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, trades, wins, losses, scratches, exclusions, days
    case fromDay = "from_day"
    case toDay = "to_day"
    case winRate = "win_rate"
    case winRateCause = "win_rate_cause"
    case expectancyGrossR = "expectancy_gross_r"
    case expectancyGrossRCause = "expectancy_gross_r_cause"
    case expectancyGrossUsd = "expectancy_gross_usd"
    case expectancyGrossUsdCause = "expectancy_gross_usd_cause"
    case averageWinGrossR = "average_win_gross_r"
    case averageWinGrossRCause = "average_win_gross_r_cause"
    case averageLossGrossR = "average_loss_gross_r"
    case averageLossGrossRCause = "average_loss_gross_r_cause"
    case profitFactorGross = "profit_factor_gross"
    case profitFactorGrossCause = "profit_factor_gross_cause"
    case maxDrawdownGrossR = "max_drawdown_gross_r"
    case maxDrawdownGrossUsd = "max_drawdown_gross_usd"
    case resultGrossR = "result_gross_r"
    case resultGrossUsd = "result_gross_usd"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    fromDay = try c.decode(WireDate.self, forKey: .fromDay)
    toDay = try c.decode(WireDate.self, forKey: .toDay)
    trades = try c.decode(Int.self, forKey: .trades)
    wins = try c.decode(Int.self, forKey: .wins)
    losses = try c.decode(Int.self, forKey: .losses)
    scratches = try c.decode(Int.self, forKey: .scratches)
    exclusions = try c.decode([PerformanceExclusionV1].self, forKey: .exclusions)
    winRate = try c.decodeCaused(.winRate, cause: .winRateCause)
    expectancyGrossR = try c.decodeCaused(.expectancyGrossR, cause: .expectancyGrossRCause)
    expectancyGrossUsd = try c.decodeCaused(.expectancyGrossUsd, cause: .expectancyGrossUsdCause)
    averageWinGrossR = try c.decodeCaused(.averageWinGrossR, cause: .averageWinGrossRCause)
    averageLossGrossR = try c.decodeCaused(.averageLossGrossR, cause: .averageLossGrossRCause)
    profitFactorGross = try c.decodeCaused(.profitFactorGross, cause: .profitFactorGrossCause)
    maxDrawdownGrossR = try c.decode(DecimalString.self, forKey: .maxDrawdownGrossR)
    maxDrawdownGrossUsd = try c.decode(DecimalString.self, forKey: .maxDrawdownGrossUsd)
    resultGrossR = try c.decode(DecimalString.self, forKey: .resultGrossR)
    resultGrossUsd = try c.decode(DecimalString.self, forKey: .resultGrossUsd)
    days = try c.decode([PerformanceDayV1].self, forKey: .days)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(environment, forKey: .environment)
    try c.encode(fromDay, forKey: .fromDay)
    try c.encode(toDay, forKey: .toDay)
    try c.encode(trades, forKey: .trades)
    try c.encode(wins, forKey: .wins)
    try c.encode(losses, forKey: .losses)
    try c.encode(scratches, forKey: .scratches)
    try c.encode(exclusions, forKey: .exclusions)
    try c.encodeCaused(winRate, .winRate, cause: .winRateCause)
    try c.encodeCaused(expectancyGrossR, .expectancyGrossR, cause: .expectancyGrossRCause)
    try c.encodeCaused(expectancyGrossUsd, .expectancyGrossUsd, cause: .expectancyGrossUsdCause)
    try c.encodeCaused(averageWinGrossR, .averageWinGrossR, cause: .averageWinGrossRCause)
    try c.encodeCaused(averageLossGrossR, .averageLossGrossR, cause: .averageLossGrossRCause)
    try c.encodeCaused(profitFactorGross, .profitFactorGross, cause: .profitFactorGrossCause)
    try c.encode(maxDrawdownGrossR, forKey: .maxDrawdownGrossR)
    try c.encode(maxDrawdownGrossUsd, forKey: .maxDrawdownGrossUsd)
    try c.encode(resultGrossR, forKey: .resultGrossR)
    try c.encode(resultGrossUsd, forKey: .resultGrossUsd)
    try c.encode(days, forKey: .days)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

extension KeyedDecodingContainer {
  /// A nullable decimal and its nullable cause, both keys required.
  func decodeCaused(_ key: Key, cause causeKey: Key) throws -> CausedDecimal {
    CausedDecimal(value: try decodeNullable(DecimalString.self, forKey: key),
      cause: try decodeNullable(String.self, forKey: causeKey))
  }
}

extension KeyedEncodingContainer {
  mutating func encodeCaused(_ caused: CausedDecimal, _ key: Key, cause causeKey: Key) throws {
    try encodeNullable(caused.value, forKey: key)
    try encodeNullable(caused.cause, forKey: causeKey)
  }
}
