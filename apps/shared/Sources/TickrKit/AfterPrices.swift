import Foundation

// Swift mirrors of the prices-after and what-if parts of day-v1 and skipped-v1 in
// src/tickr/api/contract.py: where the price went after a trade's exit or a skipped signal,
// and what a skipped signal would have made.

/// The price a set number of minutes after a moment, from the captured M1 bars.
public struct PriceAfterV1: Codable, Hashable, Sendable {
  public let minutes: Int
  public let at: WireTime
  /// Close of the bar at `at`; nil with `cause` when no bar was captured for that minute.
  public let price: DecimalString?
  /// Price change from the exit (or the signal's entry) per share, in USD; nil with `cause`.
  public let changeUsd: DecimalString?
  public let cause: String?
  /// `cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case minutes, at, price, cause
    case changeUsd = "change_usd"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    minutes = try c.decode(Int.self, forKey: .minutes)
    at = try c.decode(WireTime.self, forKey: .at)
    price = try c.decodeNullable(DecimalString.self, forKey: .price)
    changeUsd = try c.decodeNullable(DecimalString.self, forKey: .changeUsd)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(minutes, forKey: .minutes)
    try c.encode(at, forKey: .at)
    try c.encodeNullable(price, forKey: .price)
    try c.encodeNullable(changeUsd, forKey: .changeUsd)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }
}

/// How a what-if replay of a skipped signal ended.
public enum WhatIfExit: String, Codable, Sendable {
  case stop
  case strategyExit = "strategy_exit"
  case flatten
  /// The captured bars ran out with the replay still open.
  case endOfData = "end_of_data"
}

/// What a skipped signal would have made had it been taken; every figure nil with `cause` when
/// the replay could not run.
public struct WhatIfV1: Codable, Hashable, Sendable {
  public let resultGrossUsd: DecimalString?
  public let resultR: DecimalString?
  public let exitReason: WhatIfExit?
  public let cause: String?
  /// `cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case cause
    case resultGrossUsd = "result_gross_usd"
    case resultR = "result_r"
    case exitReason = "exit_reason"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    resultGrossUsd = try c.decodeNullable(DecimalString.self, forKey: .resultGrossUsd)
    resultR = try c.decodeNullable(DecimalString.self, forKey: .resultR)
    exitReason = try c.decodeNullable(WhatIfExit.self, forKey: .exitReason)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(resultGrossUsd, forKey: .resultGrossUsd)
    try c.encodeNullable(resultR, forKey: .resultR)
    try c.encodeNullable(exitReason, forKey: .exitReason)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causeCodes, forKey: .causeCodes)
  }
}
