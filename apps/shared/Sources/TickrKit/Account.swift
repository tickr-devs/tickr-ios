import Foundation

// Swift mirrors of account-v1 and account-response-v1 (GET /account) in
// src/tickr/api/contract.py: the broker's own view of the account at its last read, and
// whether it matches the bot's records.

/// A position as the broker reports it.
public struct AccountPositionV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let quantity: DecimalString
  /// Average price; nil when the broker did not report it.
  public let avgPrice: DecimalString?

  enum CodingKeys: String, CodingKey {
    case symbol, quantity
    case avgPrice = "avg_price"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    avgPrice = try c.decodeNullable(DecimalString.self, forKey: .avgPrice)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(quantity, forKey: .quantity)
    try c.encodeNullable(avgPrice, forKey: .avgPrice)
  }
}

/// An open order as the broker reports it. Side, type and status are the broker's words, shown as is.
public struct AccountOrderV1: Codable, Hashable, Sendable {
  public let clientOrderId: String?
  public let symbol: String
  public let side: String
  public let type: String
  public let status: String
  public let quantity: DecimalString
  public let limitPrice: DecimalString?
  public let stopPrice: DecimalString?
  /// True when the order is in the bot's records.
  public let ours: Bool

  enum CodingKeys: String, CodingKey {
    case symbol, side, type, status, quantity, ours
    case clientOrderId = "client_order_id"
    case limitPrice = "limit_price"
    case stopPrice = "stop_price"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    clientOrderId = try c.decodeNullable(String.self, forKey: .clientOrderId)
    symbol = try c.decode(String.self, forKey: .symbol)
    side = try c.decode(String.self, forKey: .side)
    type = try c.decode(String.self, forKey: .type)
    status = try c.decode(String.self, forKey: .status)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    limitPrice = try c.decodeNullable(DecimalString.self, forKey: .limitPrice)
    stopPrice = try c.decodeNullable(DecimalString.self, forKey: .stopPrice)
    ours = try c.decode(Bool.self, forKey: .ours)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(clientOrderId, forKey: .clientOrderId)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(side, forKey: .side)
    try c.encode(type, forKey: .type)
    try c.encode(status, forKey: .status)
    try c.encode(quantity, forKey: .quantity)
    try c.encodeNullable(limitPrice, forKey: .limitPrice)
    try c.encodeNullable(stopPrice, forKey: .stopPrice)
    try c.encode(ours, forKey: .ours)
  }
}

/// The account's money at the bot's latest successful balance read. Display only: no limit or
/// decision of the bot reads it (limits live in the platform settings).
public struct AccountBalances: Hashable, Sendable {
  /// Net liquidation value: cash plus positions at market.
  public let equityUsd: DecimalString
  /// Day (intraday) buying power.
  public let buyingPowerUsd: DecimalString
  public let overnightBuyingPowerUsd: DecimalString
  public let cashUsd: DecimalString
  /// Positions at market.
  public let positionsValueUsd: DecimalString
  public let unrealizedPlUsd: DecimalString
  public let dayPlUsd: DecimalString
  public let maintenanceMarginUsd: DecimalString
  public let marginCalls: Int
  /// Day trades the broker still allows; nil means no limit.
  public let dayTradesLeft: Int?
}

public struct AccountV1: Codable, Hashable, Sendable {
  public let readAt: WireTime
  /// Nil until a balance read succeeds.
  public let equityUsd: DecimalString?
  /// Day buying power; nil until a balance read succeeds.
  public let buyingPowerUsd: DecimalString?
  public let positions: [AccountPositionV1]
  public let orders: [AccountOrderV1]
  public let matchesRecords: Bool
  /// What differs from the bot's records, in the bot's words; nil when everything matches.
  public let mismatch: String?
  /// When the balances were read; nil until a balance read succeeds.
  public let balanceReadAt: WireTime?
  public let cashUsd: DecimalString?
  public let positionsValueUsd: DecimalString?
  public let unrealizedPlUsd: DecimalString?
  public let dayPlUsd: DecimalString?
  public let overnightBuyingPowerUsd: DecimalString?
  public let maintenanceMarginUsd: DecimalString?
  public let marginCalls: Int?
  /// Nil with a balance read means no limit.
  public let dayTradesLeft: Int?
  /// The broker's name for the account kind ("Individual Margin"); never an id or number.
  public let accountLabel: String?
  public let schemaVersion: Int

  enum CodingKeys: String, CodingKey {
    case positions, orders, mismatch
    case readAt = "read_at"
    case equityUsd = "equity_usd"
    case buyingPowerUsd = "buying_power_usd"
    case matchesRecords = "matches_records"
    case balanceReadAt = "balance_read_at"
    case cashUsd = "cash_usd"
    case positionsValueUsd = "positions_value_usd"
    case unrealizedPlUsd = "unrealized_pl_usd"
    case dayPlUsd = "day_pl_usd"
    case overnightBuyingPowerUsd = "overnight_buying_power_usd"
    case maintenanceMarginUsd = "maintenance_margin_usd"
    case marginCalls = "margin_calls"
    case dayTradesLeft = "day_trades_left"
    case accountLabel = "account_label"
    case schemaVersion = "schema_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try c.decodeVersion(forKey: .schemaVersion, expected: Wire.accountSchemaVersion)
    readAt = try c.decode(WireTime.self, forKey: .readAt)
    equityUsd = try c.decodeNullable(DecimalString.self, forKey: .equityUsd)
    buyingPowerUsd = try c.decodeNullable(DecimalString.self, forKey: .buyingPowerUsd)
    positions = try c.decode([AccountPositionV1].self, forKey: .positions)
    orders = try c.decode([AccountOrderV1].self, forKey: .orders)
    matchesRecords = try c.decode(Bool.self, forKey: .matchesRecords)
    mismatch = try c.decodeNullable(String.self, forKey: .mismatch)
    // Added after version 1 shipped: an older bot's file has no balance read.
    balanceReadAt = try c.decodeIfPresent(WireTime.self, forKey: .balanceReadAt)
    cashUsd = try c.decodeIfPresent(DecimalString.self, forKey: .cashUsd)
    positionsValueUsd = try c.decodeIfPresent(DecimalString.self, forKey: .positionsValueUsd)
    unrealizedPlUsd = try c.decodeIfPresent(DecimalString.self, forKey: .unrealizedPlUsd)
    dayPlUsd = try c.decodeIfPresent(DecimalString.self, forKey: .dayPlUsd)
    overnightBuyingPowerUsd = try c.decodeIfPresent(DecimalString.self, forKey: .overnightBuyingPowerUsd)
    maintenanceMarginUsd = try c.decodeIfPresent(DecimalString.self, forKey: .maintenanceMarginUsd)
    marginCalls = try c.decodeIfPresent(Int.self, forKey: .marginCalls)
    dayTradesLeft = try c.decodeIfPresent(Int.self, forKey: .dayTradesLeft)
    accountLabel = try c.decodeIfPresent(String.self, forKey: .accountLabel)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(readAt, forKey: .readAt)
    try c.encodeNullable(equityUsd, forKey: .equityUsd)
    try c.encodeNullable(buyingPowerUsd, forKey: .buyingPowerUsd)
    try c.encode(positions, forKey: .positions)
    try c.encode(orders, forKey: .orders)
    try c.encode(matchesRecords, forKey: .matchesRecords)
    try c.encodeNullable(mismatch, forKey: .mismatch)
    try c.encodeNullable(balanceReadAt, forKey: .balanceReadAt)
    try c.encodeNullable(cashUsd, forKey: .cashUsd)
    try c.encodeNullable(positionsValueUsd, forKey: .positionsValueUsd)
    try c.encodeNullable(unrealizedPlUsd, forKey: .unrealizedPlUsd)
    try c.encodeNullable(dayPlUsd, forKey: .dayPlUsd)
    try c.encodeNullable(overnightBuyingPowerUsd, forKey: .overnightBuyingPowerUsd)
    try c.encodeNullable(maintenanceMarginUsd, forKey: .maintenanceMarginUsd)
    try c.encodeNullable(marginCalls, forKey: .marginCalls)
    try c.encodeNullable(dayTradesLeft, forKey: .dayTradesLeft)
    try c.encodeNullable(accountLabel, forKey: .accountLabel)
    try c.encode(schemaVersion, forKey: .schemaVersion)
  }

  /// The balances of the latest successful balance read; nil until one succeeds.
  public var balances: AccountBalances? {
    guard balanceReadAt != nil, let equityUsd, let buyingPowerUsd, let overnightBuyingPowerUsd,
      let cashUsd, let positionsValueUsd, let unrealizedPlUsd, let dayPlUsd, let maintenanceMarginUsd,
      let marginCalls
    else { return nil }
    return AccountBalances(
      equityUsd: equityUsd, buyingPowerUsd: buyingPowerUsd, overnightBuyingPowerUsd: overnightBuyingPowerUsd,
      cashUsd: cashUsd, positionsValueUsd: positionsValueUsd, unrealizedPlUsd: unrealizedPlUsd, dayPlUsd: dayPlUsd,
      maintenanceMarginUsd: maintenanceMarginUsd, marginCalls: marginCalls, dayTradesLeft: dayTradesLeft)
  }
}

/// GET /account: the last broker read and how old it is.
public struct AccountResponseV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let account: AccountV1
  public let ageSeconds: DecimalString
  public let stale: Bool
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case account, stale
    case servedAt = "served_at"
    case ageSeconds = "age_seconds"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    account = try c.decode(AccountV1.self, forKey: .account)
    ageSeconds = try c.decode(DecimalString.self, forKey: .ageSeconds)
    stale = try c.decode(Bool.self, forKey: .stale)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(servedAt, forKey: .servedAt)
    try c.encode(account, forKey: .account)
    try c.encode(ageSeconds, forKey: .ageSeconds)
    try c.encode(stale, forKey: .stale)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}

/// What the account card shows of a broker read, without when it was read or served: motion
/// beside the account keys on it, so a read that finds the same account moves nothing.
public struct AccountState: Hashable, Sendable {
  public let balances: AccountBalances?
  public let accountLabel: String?
  public let positions: [AccountPositionV1]
  public let orders: [AccountOrderV1]
  public let matchesRecords: Bool
  public let mismatch: String?
  public let stale: Bool
}

extension AccountResponseV1 {
  /// The account as it stands, without the read's times (`readAt`, `servedAt`, `ageSeconds`).
  public var state: AccountState {
    AccountState(
      balances: account.balances, accountLabel: account.accountLabel, positions: account.positions,
      orders: account.orders, matchesRecords: account.matchesRecords, mismatch: account.mismatch, stale: stale)
  }
}
