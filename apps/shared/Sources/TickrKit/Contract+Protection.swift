import Foundation

// Swift mirror of the protection values in GET /status (src/tickr/api/contract.py, backlog S5).

/// A protection setting new entries are admitted under now (backlog S5). `adoptedAt` is when the running bot
/// adopted a tightening of it; nil when it holds the value the bot started with.
public struct ProtectionValue: Codable, Hashable, Sendable {
  public let key: String
  public let value: String
  public let adoptedAt: WireTime?

  enum CodingKeys: String, CodingKey {
    case key, value
    case adoptedAt = "adopted_at"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    value = try c.decode(String.self, forKey: .value)
    adoptedAt = try c.decodeNullable(WireTime.self, forKey: .adoptedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(key, forKey: .key)
    try c.encode(value, forKey: .value)
    try c.encodeNullable(adoptedAt, forKey: .adoptedAt)
  }
}
