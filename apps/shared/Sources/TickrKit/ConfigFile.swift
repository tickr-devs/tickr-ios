import Foundation

// Swift mirror of config-v1 (GET /config) in src/tickr/api/contract.py: the bot's
// configuration file as it is on disk, read-only, with whether it loads now.

/// One key of the file: its value as TOML text and the comment that says what it is.
public struct ConfigKeyV1: Codable, Hashable, Sendable {
  public let key: String
  /// The value as TOML text, such as `"a name"`, `20` or `[1, 2, 3]`.
  public let value: String
  /// What the key is, its unit and who reads it; empty when the file has no comment for it.
  public let comment: String
}

/// One table of the file, keys in file order. `name` is its dotted path as the header is
/// written (`environments.<name>`); empty for keys before the first header.
public struct ConfigSectionV1: Codable, Hashable, Sendable {
  public let name: String
  public let keys: [ConfigKeyV1]
}

/// GET /config.
public struct ConfigV1: Codable, Hashable, Sendable {
  /// The file's path relative to the bot's folder, such as `config/bot.toml`.
  public let file: String
  /// SHA-256 of the file as it is now.
  public let digest: String
  /// The file is no longer the one the API loaded: running processes use the old values until
  /// they restart.
  public let changedSinceStart: Bool
  /// The file loads now, as the next start of the bot would load it.
  public let valid: Bool
  /// Why it does not load; nil when valid.
  public let error: String?
  /// Empty when the file is not readable TOML.
  public let sections: [ConfigSectionV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case file, digest, valid, error, sections
    case changedSinceStart = "changed_since_start"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    file = try c.decode(String.self, forKey: .file)
    digest = try c.decode(String.self, forKey: .digest)
    changedSinceStart = try c.decode(Bool.self, forKey: .changedSinceStart)
    valid = try c.decode(Bool.self, forKey: .valid)
    error = try c.decodeNullable(String.self, forKey: .error)
    sections = try c.decode([ConfigSectionV1].self, forKey: .sections)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(file, forKey: .file)
    try c.encode(digest, forKey: .digest)
    try c.encode(changedSinceStart, forKey: .changedSinceStart)
    try c.encode(valid, forKey: .valid)
    try c.encodeNullable(error, forKey: .error)
    try c.encode(sections, forKey: .sections)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
