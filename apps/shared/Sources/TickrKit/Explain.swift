import Foundation

// Swift mirror of explain-v1 in src/tickr/api/contract.py: why the strategy decided what it
// decided on one bar of one symbol, check by check.

/// What the strategy decided on the bar (wire values of the Python contract).
public enum Verdict: String, Codable, Sendable {
  case ignore = "IGNORE"
  case watch = "WATCH"
  case enter = "ENTER"
  case hold = "HOLD"
  case exit = "EXIT"
}

/// What the platform's admission did with the decision.
public enum Admission: String, Codable, Sendable {
  case taken, refused
  case notEvaluated = "not_evaluated"
  case notApplicable = "not_applicable"
}

/// One rule the strategy checked: `measured operator threshold`, with its outcome.
public struct CheckV1: Codable, Hashable, Sendable {
  public let rule: String
  public let measured: DecimalString?
  public let `operator`: String
  public let threshold: DecimalString?
  public let passed: Bool
  public let note: String
  /// The rule is one the strategies record as a price against their setup's trigger (the
  /// threshold is the trigger): set by the bot from the rule, never from the values. False from
  /// an older bot.
  public let againstTrigger: Bool

  enum CodingKeys: String, CodingKey {
    case rule, measured, `operator`, threshold, passed, note
    case againstTrigger = "against_trigger"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    rule = try c.decode(String.self, forKey: .rule)
    measured = try c.decodeNullable(DecimalString.self, forKey: .measured)
    `operator` = try c.decode(String.self, forKey: .operator)
    threshold = try c.decodeNullable(DecimalString.self, forKey: .threshold)
    passed = try c.decode(Bool.self, forKey: .passed)
    note = try c.decode(String.self, forKey: .note)
    // Added after version 1 shipped: absent from an older bot's documents.
    againstTrigger = try c.decodeIfPresent(Bool.self, forKey: .againstTrigger) ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(rule, forKey: .rule)
    try c.encodeNullable(measured, forKey: .measured)
    try c.encode(`operator`, forKey: .operator)
    try c.encodeNullable(threshold, forKey: .threshold)
    try c.encode(passed, forKey: .passed)
    try c.encode(note, forKey: .note)
    try c.encode(againstTrigger, forKey: .againstTrigger)
  }
}

public struct ExplainV1: Codable, Hashable, Sendable {
  public let environment: String
  public let day: WireDate
  public let symbol: String
  public let decidedAt: WireTime
  public let barStart: WireTime
  public let strategy: String
  public let version: String
  public let verdict: Verdict
  public let setup: String?
  public let admission: Admission
  public let refusalCause: String?
  public let firstFailedCheck: String?
  public let checks: [CheckV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, day, symbol, strategy, version, verdict, setup, admission, checks
    case decidedAt = "decided_at"
    case barStart = "bar_start"
    case refusalCause = "refusal_cause"
    case firstFailedCheck = "first_failed_check"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    day = try c.decode(WireDate.self, forKey: .day)
    symbol = try c.decode(String.self, forKey: .symbol)
    decidedAt = try c.decode(WireTime.self, forKey: .decidedAt)
    barStart = try c.decode(WireTime.self, forKey: .barStart)
    strategy = try c.decode(String.self, forKey: .strategy)
    version = try c.decode(String.self, forKey: .version)
    verdict = try c.decode(Verdict.self, forKey: .verdict)
    setup = try c.decodeNullable(String.self, forKey: .setup)
    admission = try c.decode(Admission.self, forKey: .admission)
    refusalCause = try c.decodeNullable(String.self, forKey: .refusalCause)
    firstFailedCheck = try c.decodeNullable(String.self, forKey: .firstFailedCheck)
    checks = try c.decode([CheckV1].self, forKey: .checks)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(environment, forKey: .environment)
    try c.encode(day, forKey: .day)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(decidedAt, forKey: .decidedAt)
    try c.encode(barStart, forKey: .barStart)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(version, forKey: .version)
    try c.encode(verdict, forKey: .verdict)
    try c.encodeNullable(setup, forKey: .setup)
    try c.encode(admission, forKey: .admission)
    try c.encodeNullable(refusalCause, forKey: .refusalCause)
    try c.encodeNullable(firstFailedCheck, forKey: .firstFailedCheck)
    try c.encode(checks, forKey: .checks)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
