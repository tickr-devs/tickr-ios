import Foundation

// Swift mirror of trade-whatif-v1 (GET /trades/whatif) in src/tickr/api/contract.py: what
// another strategy version would have done on one trade's symbol and day. Simulated.

/// One trade the other version would have made that day.
public struct TradeWhatIfTradeV1: Codable, Hashable, Sendable {
  /// When the version decided to enter (its decision bar's start).
  public let signalAt: WireTime
  public let openedAt: WireTime
  public let entryPrice: DecimalString
  public let stop: DecimalString
  public let closedAt: WireTime
  public let exitPrice: DecimalString
  public let exitReason: WhatIfExit
  /// Result per share in R.
  public let resultR: DecimalString
  /// The version's own quantity; nil when it chose none (then no USD result).
  public let quantity: DecimalString?
  public let resultGrossUsd: DecimalString?

  enum CodingKeys: String, CodingKey {
    case stop, quantity
    case signalAt = "signal_at"
    case openedAt = "opened_at"
    case entryPrice = "entry_price"
    case closedAt = "closed_at"
    case exitPrice = "exit_price"
    case exitReason = "exit_reason"
    case resultR = "result_r"
    case resultGrossUsd = "result_gross_usd"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    signalAt = try c.decode(WireTime.self, forKey: .signalAt)
    openedAt = try c.decode(WireTime.self, forKey: .openedAt)
    entryPrice = try c.decode(DecimalString.self, forKey: .entryPrice)
    stop = try c.decode(DecimalString.self, forKey: .stop)
    closedAt = try c.decode(WireTime.self, forKey: .closedAt)
    exitPrice = try c.decode(DecimalString.self, forKey: .exitPrice)
    exitReason = try c.decode(WhatIfExit.self, forKey: .exitReason)
    resultR = try c.decode(DecimalString.self, forKey: .resultR)
    quantity = try c.decodeNullable(DecimalString.self, forKey: .quantity)
    resultGrossUsd = try c.decodeNullable(DecimalString.self, forKey: .resultGrossUsd)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(signalAt, forKey: .signalAt)
    try c.encode(openedAt, forKey: .openedAt)
    try c.encode(entryPrice, forKey: .entryPrice)
    try c.encode(stop, forKey: .stop)
    try c.encode(closedAt, forKey: .closedAt)
    try c.encode(exitPrice, forKey: .exitPrice)
    try c.encode(exitReason, forKey: .exitReason)
    try c.encode(resultR, forKey: .resultR)
    try c.encodeNullable(quantity, forKey: .quantity)
    try c.encodeNullable(resultGrossUsd, forKey: .resultGrossUsd)
  }
}

/// What the simulation did with each entry decision of the version that day.
public struct TradeWhatIfSignalsV1: Codable, Hashable, Sendable {
  public let filled: Int
  /// The price never came into the entry window.
  public let missed: Int
  /// Live admission would refuse it on time alone.
  public let rejected: Int
  /// A simulated position of the symbol was already open.
  public let ignored: Int
}

/// GET /trades/whatif: another version on one trade's symbol and day. Every number nil and no
/// trades, with `cause`, when it could not be computed.
public struct TradeWhatIfV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let symbol: String
  /// The strategy folder replayed.
  public let folder: String
  public let strategy: String?
  public let version: String?
  public let signals: TradeWhatIfSignalsV1?
  public let trades: [TradeWhatIfTradeV1]
  public let resultR: DecimalString?
  /// Nil when a trade has no quantity.
  public let resultGrossUsd: DecimalString?
  public let cause: String?
  public let apiVersion: Int
  /// The codes of `cause` (added after version 1 shipped: empty from an older API).
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case day, symbol, folder, strategy, version, signals, trades, cause
    case causeCodes = "cause_codes"
    case resultR = "result_r"
    case resultGrossUsd = "result_gross_usd"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    symbol = try c.decode(String.self, forKey: .symbol)
    folder = try c.decode(String.self, forKey: .folder)
    strategy = try c.decodeNullable(String.self, forKey: .strategy)
    version = try c.decodeNullable(String.self, forKey: .version)
    signals = try c.decodeNullable(TradeWhatIfSignalsV1.self, forKey: .signals)
    trades = try c.decode([TradeWhatIfTradeV1].self, forKey: .trades)
    resultR = try c.decodeNullable(DecimalString.self, forKey: .resultR)
    resultGrossUsd = try c.decodeNullable(DecimalString.self, forKey: .resultGrossUsd)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(folder, forKey: .folder)
    try c.encodeNullable(strategy, forKey: .strategy)
    try c.encodeNullable(version, forKey: .version)
    try c.encodeNullable(signals, forKey: .signals)
    try c.encode(trades, forKey: .trades)
    try c.encodeNullable(resultR, forKey: .resultR)
    try c.encodeNullable(resultGrossUsd, forKey: .resultGrossUsd)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// Why it could not be computed, in the person's language (the bot's words for an unknown code).
  public var causeText: String? { ApiText.prose(causeCodes, text: cause) }
}
