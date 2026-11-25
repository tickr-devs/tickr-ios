import Foundation

// Swift mirror of the settings API (backlog S4) in src/tickr/api/contract.py:
// settings-schema-v1 (GET /settings/schema), settings-values-v1 (GET /settings/values) and
// settings-draft-v1 (POST /settings/validate). Read and validate only; nothing is applied.
// Kinds, units, timings and causes stay strings here until a screen needs to switch on them.

/// One owner setting: its kind, unit, bounds, step, words and the effect of a change.
public struct SettingSpecV1: Codable, Hashable, Sendable {
  /// `platform` (config/bot.toml) or a strategy folder.
  public let owner: String
  /// The dotted `table.key` inside the owner's file.
  public let key: String
  /// `int`, `decimal` or `bool`.
  public let kind: String
  public let unit: String
  public let group: String
  public let descriptionEn: String
  public let descriptionEs: String
  /// When a change that does not loosen protection applies: `at_once`, `when_flat`, `next_session`.
  public let applies: String
  /// The direction that loosens protection (`raise`, `lower`, `never`): next session, Face ID.
  public let loosens: String
  public let needsFaceId: Bool
  public let requiresRetraining: Bool
  public let minimum: DecimalString?
  public let minimumInclusive: Bool
  public let maximum: DecimalString?
  public let step: DecimalString?

  enum CodingKeys: String, CodingKey {
    case owner, key, kind, unit, group, applies, loosens, minimum, maximum, step
    case descriptionEn = "description_en"
    case descriptionEs = "description_es"
    case needsFaceId = "needs_face_id"
    case requiresRetraining = "requires_retraining"
    case minimumInclusive = "minimum_inclusive"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    owner = try c.decode(String.self, forKey: .owner)
    key = try c.decode(String.self, forKey: .key)
    kind = try c.decode(String.self, forKey: .kind)
    unit = try c.decode(String.self, forKey: .unit)
    group = try c.decode(String.self, forKey: .group)
    descriptionEn = try c.decode(String.self, forKey: .descriptionEn)
    descriptionEs = try c.decode(String.self, forKey: .descriptionEs)
    applies = try c.decode(String.self, forKey: .applies)
    loosens = try c.decode(String.self, forKey: .loosens)
    needsFaceId = try c.decode(Bool.self, forKey: .needsFaceId)
    requiresRetraining = try c.decode(Bool.self, forKey: .requiresRetraining)
    minimum = try c.decodeNullable(DecimalString.self, forKey: .minimum)
    minimumInclusive = try c.decode(Bool.self, forKey: .minimumInclusive)
    maximum = try c.decodeNullable(DecimalString.self, forKey: .maximum)
    step = try c.decodeNullable(DecimalString.self, forKey: .step)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(owner, forKey: .owner)
    try c.encode(key, forKey: .key)
    try c.encode(kind, forKey: .kind)
    try c.encode(unit, forKey: .unit)
    try c.encode(group, forKey: .group)
    try c.encode(descriptionEn, forKey: .descriptionEn)
    try c.encode(descriptionEs, forKey: .descriptionEs)
    try c.encode(applies, forKey: .applies)
    try c.encode(loosens, forKey: .loosens)
    try c.encode(needsFaceId, forKey: .needsFaceId)
    try c.encode(requiresRetraining, forKey: .requiresRetraining)
    try c.encodeNullable(minimum, forKey: .minimum)
    try c.encode(minimumInclusive, forKey: .minimumInclusive)
    try c.encodeNullable(maximum, forKey: .maximum)
    try c.encodeNullable(step, forKey: .step)
  }
}

/// A rule across two keys of one owner's file: `left` `compare` (`<` or `<=`) `right`.
public struct SettingRuleV1: Codable, Hashable, Sendable {
  public let owner: String
  public let name: String
  public let left: String
  public let compare: String
  public let right: String
  public let descriptionEn: String
  public let descriptionEs: String

  enum CodingKeys: String, CodingKey {
    case owner, name, left, compare, right
    case descriptionEn = "description_en"
    case descriptionEs = "description_es"
  }
}

/// GET /settings/schema.
public struct SettingsSchemaV1: Codable, Hashable, Sendable {
  public let settings: [SettingSpecV1]
  public let rules: [SettingRuleV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case settings, rules
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    settings = try c.decode([SettingSpecV1].self, forKey: .settings)
    rules = try c.decode([SettingRuleV1].self, forKey: .rules)
  }
}

/// One owner's file as it is on disk now: its path relative to the bot's folder and SHA-256.
public struct SettingsFileV1: Codable, Hashable, Sendable {
  public let owner: String
  public let file: String
  public let digest: String
}

/// A setting's value in its owner's file now, as TOML text; nil when the file has no such key.
public struct SettingValueV1: Codable, Hashable, Sendable {
  public let owner: String
  public let key: String
  public let value: String?

  enum CodingKeys: String, CodingKey {
    case owner, key, value
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    owner = try c.decode(String.self, forKey: .owner)
    key = try c.decode(String.self, forKey: .key)
    value = try c.decodeNullable(String.self, forKey: .value)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(owner, forKey: .owner)
    try c.encode(key, forKey: .key)
    try c.encodeNullable(value, forKey: .value)
  }
}

/// GET /settings/values.
public struct SettingsValuesV1: Codable, Hashable, Sendable {
  public let files: [SettingsFileV1]
  public let values: [SettingValueV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case files, values
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    files = try c.decode([SettingsFileV1].self, forKey: .files)
    values = try c.decode([SettingValueV1].self, forKey: .values)
  }
}

/// Why one key of a draft is refused: a typed cause and its detail.
public struct SettingRefusalV1: Codable, Hashable, Sendable {
  public let owner: String
  public let key: String
  public let cause: String
  public let detail: String
}

/// What one draft key would do against the value on disk now.
public struct SettingChangeV1: Codable, Hashable, Sendable {
  public let owner: String
  public let key: String
  public let current: String
  public let draft: String
  public let changed: Bool
  public let applies: String
  public let needsFaceId: Bool
  public let requiresRetraining: Bool

  enum CodingKeys: String, CodingKey {
    case owner, key, current, draft, changed, applies
    case needsFaceId = "needs_face_id"
    case requiresRetraining = "requires_retraining"
  }
}

/// POST /settings/validate: the verdict on a draft; nothing is written or applied.
public struct SettingsDraftV1: Codable, Hashable, Sendable {
  public let valid: Bool
  public let refusals: [SettingRefusalV1]
  public let changes: [SettingChangeV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case valid, refusals, changes
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    valid = try c.decode(Bool.self, forKey: .valid)
    refusals = try c.decode([SettingRefusalV1].self, forKey: .refusals)
    changes = try c.decode([SettingChangeV1].self, forKey: .changes)
  }
}
