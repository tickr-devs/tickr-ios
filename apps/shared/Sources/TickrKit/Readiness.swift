import Foundation

// Swift mirror of readiness-v1 (GET /readiness) in src/tickr/api/contract.py: the
// readiness view of Settings › Environment (Mac) and Settings › Safety (iOS). Read-only: the
// trading gate stays the single barrier, and nothing here enables an environment.

/// What a readiness check proved.
public enum ReadinessState: String, Codable, Sendable {
  case pass, fail, unknown
}

/// A readiness check, in the fixed order the bot lists them.
public enum ReadinessCode: String, Codable, Sendable {
  case cleanDays = "clean_days"
  case preflight
  case unattendedSafeguard = "unattended_safeguard"
  case keys
  case dataProbe = "data_probe"
  case tradingEnabled = "trading_enabled"
  case authorization
}

/// One readiness check of one environment.
public struct ReadinessCheckV1: Codable, Hashable, Sendable {
  public let code: ReadinessCode
  public let environment: String
  public let state: ReadinessState
  /// What was measured ("3 / 5", a New York date); nil when nothing was.
  public let value: String?
  /// The bot's detail, nil on a pass.
  public let cause: String?

  enum CodingKeys: String, CodingKey { case code, environment, state, value, cause }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    code = try c.decode(ReadinessCode.self, forKey: .code)
    environment = try c.decode(String.self, forKey: .environment)
    state = try c.decode(ReadinessState.self, forKey: .state)
    value = try c.decodeNullable(String.self, forKey: .value)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(code, forKey: .code)
    try c.encode(environment, forKey: .environment)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(value, forKey: .value)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// An environment's owner authorization file, field by field (never its statement), with the
/// trading gate's own check of it.
public struct AuthorizationRecordV1: Codable, Hashable, Sendable {
  public let file: String
  public let present: Bool
  public let environment: String?
  public let approvedOn: String?
  public let digestMatches: Bool?
  public let valid: Bool
  public let cause: String
  /// `cause` as a trading gate code (docs/api.md, "Reason codes"), with the values it names.
  public let code: String
  public let params: [String: String]

  enum CodingKeys: String, CodingKey {
    case file, present, environment, valid, cause, code, params
    case approvedOn = "approved_on"
    case digestMatches = "digest_matches"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    file = try c.decode(String.self, forKey: .file)
    present = try c.decode(Bool.self, forKey: .present)
    environment = try c.decodeNullable(String.self, forKey: .environment)
    approvedOn = try c.decodeNullable(String.self, forKey: .approvedOn)
    digestMatches = try c.decodeNullable(Bool.self, forKey: .digestMatches)
    valid = try c.decode(Bool.self, forKey: .valid)
    cause = try c.decode(String.self, forKey: .cause)
    code = try c.decode(String.self, forKey: .code)
    params = try c.decode([String: String].self, forKey: .params)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(file, forKey: .file)
    try c.encode(present, forKey: .present)
    try c.encodeNullable(environment, forKey: .environment)
    try c.encodeNullable(approvedOn, forKey: .approvedOn)
    try c.encodeNullable(digestMatches, forKey: .digestMatches)
    try c.encode(valid, forKey: .valid)
    try c.encode(cause, forKey: .cause)
    try c.encode(code, forKey: .code)
    try c.encode(params, forKey: .params)
  }
}

/// One configured environment, evaluated without switching to it.
public struct EnvironmentReadinessV1: Codable, Hashable, Sendable {
  public let name: String
  /// The environment the API process loaded.
  public let loaded: Bool
  public let tradingEnabled: Bool
  public let requiresOwnerAuthorization: Bool
  /// Nil when the API process holds none of its credential variables.
  public let keysPresent: Bool?
  /// The trading gate as if this environment were loaded.
  public let gate: Gate
  public let authorization: AuthorizationRecordV1?

  enum CodingKeys: String, CodingKey {
    case name, loaded, gate, authorization
    case tradingEnabled = "trading_enabled"
    case requiresOwnerAuthorization = "requires_owner_authorization"
    case keysPresent = "keys_present"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    loaded = try c.decode(Bool.self, forKey: .loaded)
    tradingEnabled = try c.decode(Bool.self, forKey: .tradingEnabled)
    requiresOwnerAuthorization = try c.decode(Bool.self, forKey: .requiresOwnerAuthorization)
    keysPresent = try c.decodeNullable(Bool.self, forKey: .keysPresent)
    gate = try c.decode(Gate.self, forKey: .gate)
    authorization = try c.decodeNullable(AuthorizationRecordV1.self, forKey: .authorization)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encode(loaded, forKey: .loaded)
    try c.encode(tradingEnabled, forKey: .tradingEnabled)
    try c.encode(requiresOwnerAuthorization, forKey: .requiresOwnerAuthorization)
    try c.encodeNullable(keysPresent, forKey: .keysPresent)
    try c.encode(gate, forKey: .gate)
    try c.encodeNullable(authorization, forKey: .authorization)
  }
}

/// GET /readiness: the readiness view.
public struct ReadinessV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let environment: String
  /// What an authorization record must carry (a hash of the config, not a secret).
  public let configDigest: String
  public let gate: Gate
  public let environments: [EnvironmentReadinessV1]
  public let checklist: [ReadinessCheckV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, gate, environments, checklist
    case servedAt = "served_at"
    case configDigest = "config_digest"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    environment = try c.decode(String.self, forKey: .environment)
    configDigest = try c.decode(String.self, forKey: .configDigest)
    gate = try c.decode(Gate.self, forKey: .gate)
    environments = try c.decode([EnvironmentReadinessV1].self, forKey: .environments)
    checklist = try c.decode([ReadinessCheckV1].self, forKey: .checklist)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(servedAt, forKey: .servedAt)
    try c.encode(environment, forKey: .environment)
    try c.encode(configDigest, forKey: .configDigest)
    try c.encode(gate, forKey: .gate)
    try c.encode(environments, forKey: .environments)
    try c.encode(checklist, forKey: .checklist)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
