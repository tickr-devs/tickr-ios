import Foundation

// status-v1's trading gate and fences, with the reason codes they carry (docs/api.md, "Reason
// codes").

/// Reason codes the clients themselves rely on (docs/api.md, "Reason codes").
/// A cause's code and the values it names: one part of a cause the API wrote in English
/// (`<field>_codes`, docs/api.md, "Reason codes"). Clients show the English text when the code is
/// `unrecognized` or one they do not know.
public struct ReasonV1: Codable, Hashable, Sendable {
  public let code: String
  public let params: [String: String]
}

public enum ReasonCode {
  /// A reason recorded before the bot sent codes (`code` and `params` were added after version 1
  /// shipped); clients show the reason's text.
  public static let unrecorded = "unrecorded"
}

public struct Gate: Codable, Hashable, Sendable {
  public let open: Bool
  public let cause: String
  /// `cause` as a code (docs/api.md, "Reason codes"), with the values it names.
  public let code: String
  public let params: [String: String]

  enum CodingKeys: String, CodingKey { case open, cause, code, params }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    open = try c.decode(Bool.self, forKey: .open)
    cause = try c.decode(String.self, forKey: .cause)
    code = try c.decodeIfPresent(String.self, forKey: .code) ?? ReasonCode.unrecorded
    params = try c.decodeIfPresent([String: String].self, forKey: .params) ?? [:]
  }
}

public struct Fence: Codable, Hashable, Sendable {
  public let kind: String
  public let since: WireTime
  public let text: String
  /// `text` as a code, by kind (docs/api.md, "Reason codes"), with the values it names.
  public let code: String
  public let params: [String: String]

  enum CodingKeys: String, CodingKey { case kind, since, text, code, params }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    kind = try c.decode(String.self, forKey: .kind)
    since = try c.decode(WireTime.self, forKey: .since)
    text = try c.decode(String.self, forKey: .text)
    code = try c.decodeIfPresent(String.self, forKey: .code) ?? ReasonCode.unrecorded
    params = try c.decodeIfPresent([String: String].self, forKey: .params) ?? [:]
  }
}
