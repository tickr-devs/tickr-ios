import Foundation

/// What the flow knows about a trade's broker-side stop: confirmed by the broker, waiting for
/// confirmation, never confirmed before the trade ended, or not known.
public enum FlowStopState: String, Codable, Sendable {
  case verified, pending
  case neverVerified = "never_verified"
  case unknown
}

/// One trade of the day and the state of its broker-side stop.
public struct FlowStopV1: Codable, Hashable, Sendable {
  public let tradeId: String
  public let symbol: String
  public let state: FlowStopState
  /// The first read showing the entry filled, the first showing its stop working, and the trade's
  /// close (added after version 1 shipped: nil from an older API; nil while unknown or open).
  public let filledAt: WireTime?
  public let stopConfirmedAt: WireTime?
  public let closedAt: WireTime?

  enum CodingKeys: String, CodingKey {
    case symbol, state
    case tradeId = "trade_id"
    case filledAt = "filled_at"
    case stopConfirmedAt = "stop_confirmed_at"
    case closedAt = "closed_at"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    tradeId = try c.decode(String.self, forKey: .tradeId)
    symbol = try c.decode(String.self, forKey: .symbol)
    state = try c.decode(FlowStopState.self, forKey: .state)
    filledAt = try c.decodeIfPresent(WireTime.self, forKey: .filledAt)
    stopConfirmedAt = try c.decodeIfPresent(WireTime.self, forKey: .stopConfirmedAt)
    closedAt = try c.decodeIfPresent(WireTime.self, forKey: .closedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(tradeId, forKey: .tradeId)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(filledAt, forKey: .filledAt)
    try c.encodeNullable(stopConfirmedAt, forKey: .stopConfirmedAt)
    try c.encodeNullable(closedAt, forKey: .closedAt)
  }
}
