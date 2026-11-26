import Foundation

// Swift mirrors of decisions-v1 and skipped-v1 in src/tickr/api/contract.py: every decision on
// one symbol with its checks, and the active strategy's ENTERs that did not become a position.

/// The strategy that made a decision, by name and version.
public struct StrategyRefV1: Codable, Hashable, Sendable {
  public let name: String
  public let version: String
}

/// Why the platform refused an entry: a code from the schema's closed list, the bot's message,
/// and the window the refusal covers when it has one (a cooldown has both ends).
public struct RefusalV1: Codable, Hashable, Sendable {
  /// An AdmissionCause name, ENGINE_REFUSED or UNKNOWN (uppercase, as the schema lists them).
  public let code: String
  public let message: String
  public let since: WireTime?
  public let until: WireTime?
  /// The values `message` names, by name (docs/api.md, `refusal` → `params`).
  public let params: [String: String]

  enum CodingKeys: String, CodingKey { case code, message, since, until, params }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    code = try c.decode(String.self, forKey: .code)
    message = try c.decode(String.self, forKey: .message)
    since = try c.decodeNullable(WireTime.self, forKey: .since)
    until = try c.decodeNullable(WireTime.self, forKey: .until)
    params = try c.decode([String: String].self, forKey: .params)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(code, forKey: .code)
    try c.encode(message, forKey: .message)
    try c.encodeNullable(since, forKey: .since)
    try c.encodeNullable(until, forKey: .until)
    try c.encode(params, forKey: .params)
  }
}

/// One decision on a symbol, by the trading strategy or a shadow one, with the checks behind it.
public struct DecisionV1: Codable, Hashable, Sendable {
  public let at: WireTime
  public let action: Verdict
  public let strategy: StrategyRefV1
  /// True when a shadow strategy (an "observer" in the bot's config) made the decision; it never
  /// trades, and the apps leave its decisions out.
  public let observer: Bool
  public let checks: [CheckV1]
  /// What-if entry and stop of an ENTER that was not taken; nil for every other decision.
  public let entryPrice: DecimalString?
  public let stopPrice: DecimalString?
  /// The recorded admission: `notEvaluated` for every shadow strategy's ENTER, `notApplicable` for
  /// any other verdict.
  public let admission: Admission
  /// The single "CAUSE: detail" of a refusal; nil otherwise.
  public let refusalCause: String?
  /// The structured refusal; nil unless the platform refused the entry.
  public let refusal: RefusalV1?

  enum CodingKeys: String, CodingKey {
    case at, action, strategy, observer, checks, admission
    case entryPrice = "entry_price"
    case stopPrice = "stop_price"
    case refusalCause = "refusal_cause"
    case refusal
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
    admission = try c.decode(Admission.self, forKey: .admission)
    refusalCause = try c.decodeNullable(String.self, forKey: .refusalCause)
    refusal = try c.decodeNullable(RefusalV1.self, forKey: .refusal)
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
    try c.encode(admission, forKey: .admission)
    try c.encodeNullable(refusalCause, forKey: .refusalCause)
    try c.encodeNullable(refusal, forKey: .refusal)
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

/// An ENTER of the active strategy that did not become a position: refused by the platform, or
/// not evaluated.
public struct SkippedSignalV1: Codable, Hashable, Sendable {
  public let at: WireTime
  public let symbol: String
  public let strategy: StrategyRefV1
  /// `refused` or `notEvaluated`.
  public let admission: Admission
  /// The single "CAUSE: detail" of a refusal; nil otherwise.
  public let refusalCause: String?
  /// The structured refusal; nil unless the platform refused the entry.
  public let refusal: RefusalV1?
  /// What-if entry and stop, each nil when the record does not hold it.
  public let entryPrice: DecimalString?
  public let stopPrice: DecimalString?
  public let checks: [CheckV1]
  /// Prices at set minutes after the signal, oldest first; empty with `pricesAfterCause` when none.
  public let pricesAfter: [PriceAfterV1]
  public let pricesAfterCause: String?
  /// What the signal would have made had it been taken.
  public let whatIf: WhatIfV1
  /// `prices_after_cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let pricesAfterCauseCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case at, symbol, strategy, admission, checks
    case refusalCause = "refusal_cause"
    case refusal
    case entryPrice = "entry_price"
    case stopPrice = "stop_price"
    case pricesAfter = "prices_after"
    case pricesAfterCause = "prices_after_cause"
    case whatIf = "what_if"
    case pricesAfterCauseCodes = "prices_after_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    at = try c.decode(WireTime.self, forKey: .at)
    symbol = try c.decode(String.self, forKey: .symbol)
    strategy = try c.decode(StrategyRefV1.self, forKey: .strategy)
    admission = try c.decode(Admission.self, forKey: .admission)
    refusalCause = try c.decodeNullable(String.self, forKey: .refusalCause)
    refusal = try c.decodeNullable(RefusalV1.self, forKey: .refusal)
    entryPrice = try c.decodeNullable(DecimalString.self, forKey: .entryPrice)
    stopPrice = try c.decodeNullable(DecimalString.self, forKey: .stopPrice)
    checks = try c.decode([CheckV1].self, forKey: .checks)
    pricesAfter = try c.decode([PriceAfterV1].self, forKey: .pricesAfter)
    pricesAfterCause = try c.decodeNullable(String.self, forKey: .pricesAfterCause)
    whatIf = try c.decode(WhatIfV1.self, forKey: .whatIf)
    pricesAfterCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .pricesAfterCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(at, forKey: .at)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(admission, forKey: .admission)
    try c.encodeNullable(refusalCause, forKey: .refusalCause)
    try c.encodeNullable(refusal, forKey: .refusal)
    try c.encodeNullable(entryPrice, forKey: .entryPrice)
    try c.encodeNullable(stopPrice, forKey: .stopPrice)
    try c.encode(checks, forKey: .checks)
    try c.encode(pricesAfter, forKey: .pricesAfter)
    try c.encodeNullable(pricesAfterCause, forKey: .pricesAfterCause)
    try c.encode(whatIf, forKey: .whatIf)
    try c.encode(pricesAfterCauseCodes, forKey: .pricesAfterCauseCodes)
  }
}

/// The active strategy's ENTERs on one day that did not become a position, oldest first.
public struct SkippedV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let signals: [SkippedSignalV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, signals
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    signals = try c.decode([SkippedSignalV1].self, forKey: .signals)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(signals, forKey: .signals)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
