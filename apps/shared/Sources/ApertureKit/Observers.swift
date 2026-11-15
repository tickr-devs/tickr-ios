import Foundation

// Swift mirrors of observers-v1, decisions-v1 and skipped-v1 in src/aperture/api/contract.py:
// what the shadow strategies decided on a day, every decision on one symbol with its checks, and
// the active strategy's ENTERs that did not become a position.

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
  /// Gross result of the observer's simulated trades that day; nil when it cannot be computed.
  public let resultGrossUSD: DecimalString?
  /// Why `resultGrossUSD` is nil; nil when there is a result.
  public let resultCause: String?

  enum CodingKeys: String, CodingKey {
    case name, version, decisions
    case resultGrossUSD = "result_gross_usd"
    case resultCause = "result_cause"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    version = try c.decode(String.self, forKey: .version)
    decisions = try c.decode([ObserverDecisionV1].self, forKey: .decisions)
    resultGrossUSD = try c.decodeNullable(DecimalString.self, forKey: .resultGrossUSD)
    resultCause = try c.decodeNullable(String.self, forKey: .resultCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encode(version, forKey: .version)
    try c.encode(decisions, forKey: .decisions)
    try c.encodeNullable(resultGrossUSD, forKey: .resultGrossUSD)
    try c.encodeNullable(resultCause, forKey: .resultCause)
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

/// Why the platform refused an entry: a code from the schema's closed list, the bot's message,
/// and the window the refusal covers when it has one (a cooldown has both ends).
public struct RefusalV1: Codable, Hashable, Sendable {
  /// An AdmissionCause name, ENGINE_REFUSED or UNKNOWN (uppercase, as the schema lists them).
  public let code: String
  public let message: String
  public let since: WireTime?
  public let until: WireTime?

  enum CodingKeys: String, CodingKey { case code, message, since, until }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    code = try c.decode(String.self, forKey: .code)
    message = try c.decode(String.self, forKey: .message)
    since = try c.decodeNullable(WireTime.self, forKey: .since)
    until = try c.decodeNullable(WireTime.self, forKey: .until)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(code, forKey: .code)
    try c.encode(message, forKey: .message)
    try c.encodeNullable(since, forKey: .since)
    try c.encodeNullable(until, forKey: .until)
  }
}

/// One decision on a symbol, by the trading strategy or an observer, with the checks behind it.
public struct DecisionV1: Codable, Hashable, Sendable {
  public let at: WireTime
  public let action: Verdict
  public let strategy: StrategyRefV1
  /// True when an observer (shadow strategy) made the decision; it never trades.
  public let observer: Bool
  public let checks: [CheckV1]
  /// What-if entry and stop of an ENTER that was not taken; nil for every other decision.
  public let entryPrice: DecimalString?
  public let stopPrice: DecimalString?
  /// The recorded admission: `notEvaluated` for every observer ENTER, `notApplicable` for any
  /// other verdict.
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

  enum CodingKeys: String, CodingKey {
    case at, symbol, strategy, admission, checks
    case refusalCause = "refusal_cause"
    case refusal
    case entryPrice = "entry_price"
    case stopPrice = "stop_price"
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
