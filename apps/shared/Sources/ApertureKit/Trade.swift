import Foundation

// Swift mirror of the status-v1 trade in src/aperture/api/contract.py (its own file to keep
// Contract.swift within the file length limit).

/// A trade the bot closed today, as status-v1 lists it.
public struct Trade: Codable, Hashable, Sendable {
  public let symbol: String
  public let quantity: DecimalString
  public let entryPrice: DecimalString
  public let exitPrice: DecimalString
  public let openedAt: WireTime
  public let closedAt: WireTime
  public let exitReason: String
  public let resultGrossUsd: DecimalString
  /// What the trade risked at entry (entry to stop, times quantity), in USD; the unit of R.
  public let plannedLossUsd: DecimalString
  /// Seconds from the entry fill to the broker confirming the stop; nil when not recorded.
  public let stopConfirmedAfterSeconds: DecimalString?

  enum CodingKeys: String, CodingKey {
    case symbol, quantity
    case entryPrice = "entry_price"
    case exitPrice = "exit_price"
    case openedAt = "opened_at"
    case closedAt = "closed_at"
    case exitReason = "exit_reason"
    case resultGrossUsd = "result_gross_usd"
    case plannedLossUsd = "planned_loss_usd"
    case stopConfirmedAfterSeconds = "stop_confirmed_after_seconds"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    entryPrice = try c.decode(DecimalString.self, forKey: .entryPrice)
    exitPrice = try c.decode(DecimalString.self, forKey: .exitPrice)
    openedAt = try c.decode(WireTime.self, forKey: .openedAt)
    closedAt = try c.decode(WireTime.self, forKey: .closedAt)
    exitReason = try c.decode(String.self, forKey: .exitReason)
    resultGrossUsd = try c.decode(DecimalString.self, forKey: .resultGrossUsd)
    plannedLossUsd = try c.decode(DecimalString.self, forKey: .plannedLossUsd)
    stopConfirmedAfterSeconds = try c.decodeNullable(DecimalString.self, forKey: .stopConfirmedAfterSeconds)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(quantity, forKey: .quantity)
    try c.encode(entryPrice, forKey: .entryPrice)
    try c.encode(exitPrice, forKey: .exitPrice)
    try c.encode(openedAt, forKey: .openedAt)
    try c.encode(closedAt, forKey: .closedAt)
    try c.encode(exitReason, forKey: .exitReason)
    try c.encode(resultGrossUsd, forKey: .resultGrossUsd)
    try c.encode(plannedLossUsd, forKey: .plannedLossUsd)
    try c.encodeNullable(stopConfirmedAfterSeconds, forKey: .stopConfirmedAfterSeconds)
  }
}
