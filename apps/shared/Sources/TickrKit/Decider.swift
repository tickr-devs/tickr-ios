import Foundation

// Swift mirror of the decision makers' identities in src/tickr/api/contract.py (docs/api.md,
// "Decider"). Today every decision is a strategy's; `model` is sent only once the trained model decides.

/// A strategy's `[strategy]` name and version, as status-v1 records it.
public struct StrategyId: Codable, Hashable, Sendable {
  public let name: String
  public let version: String
  /// The settings version the decision or trade was made under (backlog S3, docs/api.md): the
  /// platform settings plus the model's bundle, or this strategy's values while the model is
  /// off. Nil when not recorded.
  public let settingsVersion: String?
  /// The document carried the key: the API's answers always do, status.json never does (an
  /// older reader of the file refuses unknown keys; GET /status adds it from the run facts).
  private let sendsSettingsVersion: Bool

  enum CodingKeys: String, CodingKey {
    case name
    case version
    case settingsVersion = "settings_version"
  }

  public init(name: String, version: String, settingsVersion: String? = nil) {
    self.name = name
    self.version = version
    self.settingsVersion = settingsVersion
    sendsSettingsVersion = true
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    version = try c.decode(String.self, forKey: .version)
    // Added after version 1 shipped: an older bot's strategy, and status.json, have no such key.
    sendsSettingsVersion = c.contains(.settingsVersion)
    settingsVersion = try c.decodeIfPresent(String.self, forKey: .settingsVersion)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encode(version, forKey: .version)
    if sendsSettingsVersion {
      try c.encodeNullable(settingsVersion, forKey: .settingsVersion)
    }
  }
}

/// What kind of decider made a decision.
public enum DeciderKind: String, Codable, Sendable {
  case strategy, model
  /// A kind a later API sends that this app does not know: read as such, so the rest of the
  /// document still reads, and never taken for a strategy or a model.
  case unrecognized

  public init(from decoder: Decoder) throws {
    self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unrecognized
  }
}

/// Who made a decision: a strategy (its `[strategy]` name and version) or a trained model bundle.
public struct DeciderV1: Codable, Hashable, Sendable {
  public let kind: DeciderKind
  public let name: String
  public let version: String
}
