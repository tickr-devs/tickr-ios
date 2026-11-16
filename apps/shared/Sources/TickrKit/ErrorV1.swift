import Foundation

/// Every non-2xx answer.
public struct ErrorV1: Codable, Hashable, Sendable {
  public let error: String
  public let cause: String
  public let apiVersion: Int
  /// The codes of `cause` (added after version 1 shipped: empty from an older API).
  public let causeCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case error, cause
    case apiVersion = "api_version"
    case causeCodes = "cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    error = try c.decode(String.self, forKey: .error)
    cause = try c.decode(String.self, forKey: .cause)
    causeCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .causeCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(error, forKey: .error)
    try c.encode(cause, forKey: .cause)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(causeCodes, forKey: .causeCodes)
  }

  /// The cause in the person's language: the bot's own words for a code this app does not know.
  public var causeText: String { ApiText.prose(causeCodes, text: cause) }
}
