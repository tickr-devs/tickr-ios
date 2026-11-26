import Foundation

// Swift mirror of the status-v1 working entry (src/tickr/api/contract.py, added after version 1
// shipped); its own file to keep Contract.swift within the file length limit.

/// An own entry order working at the broker with nothing filled yet: the Cancel entry row. A
/// fill of any part makes it a `Position` instead.
public struct WorkingEntry: Codable, Hashable, Sendable {
  public let symbol: String
  /// Shares the entry asks for.
  public let quantity: DecimalString
  public let limitPrice: DecimalString
  /// The stop the bot places once the entry fills.
  public let stopPrice: DecimalString
  /// 1 R if it fills.
  public let plannedLossUsd: DecimalString
  /// How the entry order was sent; see `EntrySend`.
  public let entry: EntrySend
  /// Why a field of `entry` is null; nil when none is.
  public let entryCause: String?
  /// The bot asked the broker to cancel it; it stays listed until a broker read shows it
  /// cancelled or filled.
  public let cancelRequested: Bool
  /// `entry_cause` as codes (docs/api.md, "Reason codes"); empty when there is none.
  public let entryCauseCodes: [ReasonV1]

  enum CodingKeys: String, CodingKey {
    case symbol, quantity, entry
    case limitPrice = "limit_price"
    case stopPrice = "stop_price"
    case plannedLossUsd = "planned_loss_usd"
    case entryCause = "entry_cause"
    case cancelRequested = "cancel_requested"
    case entryCauseCodes = "entry_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    limitPrice = try c.decode(DecimalString.self, forKey: .limitPrice)
    stopPrice = try c.decode(DecimalString.self, forKey: .stopPrice)
    plannedLossUsd = try c.decode(DecimalString.self, forKey: .plannedLossUsd)
    entry = try c.decode(EntrySend.self, forKey: .entry)
    entryCause = try c.decodeNullable(String.self, forKey: .entryCause)
    cancelRequested = try c.decode(Bool.self, forKey: .cancelRequested)
    entryCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .entryCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(quantity, forKey: .quantity)
    try c.encode(limitPrice, forKey: .limitPrice)
    try c.encode(stopPrice, forKey: .stopPrice)
    try c.encode(plannedLossUsd, forKey: .plannedLossUsd)
    try c.encode(entry, forKey: .entry)
    try c.encodeNullable(entryCause, forKey: .entryCause)
    try c.encode(cancelRequested, forKey: .cancelRequested)
    try c.encode(entryCauseCodes, forKey: .entryCauseCodes)
  }
}
