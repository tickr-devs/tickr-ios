import Foundation

// Swift mirrors of observers-v1 and decisions-v1 in src/aperture/api/contract.py: what the
// shadow strategies decided on a day, and every decision on one symbol with its checks.

/// One decision of an observer: when, on which symbol, what, and why.
public struct ObserverDecisionV1: Codable, Hashable, Sendable {
  public let at: WireTime
  public let symbol: String
  public let action: Verdict
  public let reasons: [String]
}

/// One observer (a shadow strategy version that never trades) and its day.
public struct ObserverV1: Codable, Hashable, Sendable {
  public let name: String
  public let version: String
  public let decisions: [ObserverDecisionV1]
  /// Gross result of the observer's hypothetical trades; nil while it is not computed.
  public let resultGrossUSD: DecimalString?

  enum CodingKeys: String, CodingKey {
    case name, version, decisions
    case resultGrossUSD = "result_gross_usd"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    version = try c.decode(String.self, forKey: .version)
    decisions = try c.decode([ObserverDecisionV1].self, forKey: .decisions)
    resultGrossUSD = try c.decodeNullable(DecimalString.self, forKey: .resultGrossUSD)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encode(version, forKey: .version)
    try c.encode(decisions, forKey: .decisions)
    try c.encodeNullable(resultGrossUSD, forKey: .resultGrossUSD)
  }
}

public struct ObserversV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let observers: [ObserverV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, observers
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    observers = try c.decode([ObserverV1].self, forKey: .observers)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(observers, forKey: .observers)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

/// The strategy that made a decision, by name and version.
public struct StrategyRefV1: Codable, Hashable, Sendable {
  public let name: String
  public let version: String
}

/// One decision on a symbol, by the trading strategy or an observer, with the checks behind it.
public struct DecisionV1: Codable, Hashable, Sendable {
  public let at: WireTime
  public let action: Verdict
  public let strategy: StrategyRefV1
  /// True when an observer (shadow strategy) made the decision; it never trades.
  public let observer: Bool
  public let checks: [CheckV1]
  public let entryPrice: DecimalString?
  public let stopPrice: DecimalString?

  enum CodingKeys: String, CodingKey {
    case at, action, strategy, observer, checks
    case entryPrice = "entry_price"
    case stopPrice = "stop_price"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    at = try c.decode(WireTime.self, forKey: .at)
    action = try c.decode(Verdict.self, forKey: .action)
    strategy = try c.decode(StrategyRefV1.self, forKey: .strategy)
    observer = try c.decode(Bool.self, forKey: .observer)
    checks = try c.decode([CheckV1].self, forKey: .checks)
    entryPrice = try c.decodeNullable(DecimalString.self, forKey: .entryPrice)
    stopPrice = try c.decodeNullable(DecimalString.self, forKey: .stopPrice)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(at, forKey: .at)
    try c.encode(action, forKey: .action)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(observer, forKey: .observer)
    try c.encode(checks, forKey: .checks)
    try c.encodeNullable(entryPrice, forKey: .entryPrice)
    try c.encodeNullable(stopPrice, forKey: .stopPrice)
  }
}

public struct DecisionsV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let day: WireDate
  public let decisions: [DecisionV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case symbol, day, decisions
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    symbol = try c.decode(String.self, forKey: .symbol)
    day = try c.decode(WireDate.self, forKey: .day)
    decisions = try c.decode([DecisionV1].self, forKey: .decisions)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(day, forKey: .day)
    try c.encode(decisions, forKey: .decisions)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
