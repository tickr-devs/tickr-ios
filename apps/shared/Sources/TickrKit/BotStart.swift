import Foundation

// Swift mirror of bot-start-v1 (POST /commands/start-bot) in src/tickr/api/contract.py.

/// launchd accepted the start of the bot job. The bot is not running yet: its preflight runs
/// first and may still refuse, so the status says what happened next.
public struct BotStartV1: Codable, Hashable, Sendable {
  public let requestedAt: WireTime
  /// An operator stop (from Stop) was removed first, so scheduled starts run again too.
  public let stopMarkerCleared: Bool
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case requestedAt = "requested_at"
    case stopMarkerCleared = "stop_marker_cleared"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    requestedAt = try c.decode(WireTime.self, forKey: .requestedAt)
    stopMarkerCleared = try c.decode(Bool.self, forKey: .stopMarkerCleared)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(requestedAt, forKey: .requestedAt)
    try c.encode(stopMarkerCleared, forKey: .stopMarkerCleared)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
