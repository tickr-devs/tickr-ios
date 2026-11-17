import Foundation

// Swift mirror of day-events-v1 (GET /events?date=) in src/tickr/api/contract.py: what the bot
// did on one New York date, as events a person reads. Read-only.

/// What one event says happened (`DayEventKind` in the contract).
public enum DayEventKind: String, Sendable, CaseIterable {
  case botStarted = "bot-started"
  case botStopped = "bot-stopped"
  case entrySent = "entry-sent"
  case filled
  case orderRefused = "order-refused"
  case stopPlaced = "stop-placed"
  case stopMoved = "stop-moved"
  case exitRequested = "exit-requested"
  case tradeClosed = "trade-closed"
  case fenceSet = "fence-set"
  case fenceCleared = "fence-cleared"
  case commandDone = "command-done"
  case commandRefused = "command-refused"
}

/// One event of the day; the fields its kind does not fill are nil.
public struct DayEventV1: Codable, Hashable, Sendable {
  /// The journal row it comes from: grows with time, never reused.
  public let seq: Int
  public let at: WireTime
  /// The kind as sent; `event` is nil for one this app does not know (the row is not shown).
  public let kind: String
  public let symbol: String?
  /// The order's leg: `entry`, `stop` or `exit`.
  public let leg: String?
  public let quantity: DecimalString?
  public let price: DecimalString?
  public let stopPrice: DecimalString?
  /// A fence's name, a command's kind, or the started strategy as "<name>@<version>".
  public let subject: String?
  /// Why, as the bot recorded it (an exit reason, an order refusal, how the bot stopped).
  public let cause: String?

  public var event: DayEventKind? { DayEventKind(rawValue: kind) }

  enum CodingKeys: String, CodingKey {
    case seq, at, kind, symbol, leg, quantity, price, subject, cause
    case stopPrice = "stop_price"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    seq = try c.decode(Int.self, forKey: .seq)
    at = try c.decode(WireTime.self, forKey: .at)
    kind = try c.decode(String.self, forKey: .kind)
    symbol = try c.decodeNullable(String.self, forKey: .symbol)
    leg = try c.decodeNullable(String.self, forKey: .leg)
    quantity = try c.decodeNullable(DecimalString.self, forKey: .quantity)
    price = try c.decodeNullable(DecimalString.self, forKey: .price)
    stopPrice = try c.decodeNullable(DecimalString.self, forKey: .stopPrice)
    subject = try c.decodeNullable(String.self, forKey: .subject)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(seq, forKey: .seq)
    try c.encode(at, forKey: .at)
    try c.encode(kind, forKey: .kind)
    try c.encodeNullable(symbol, forKey: .symbol)
    try c.encodeNullable(leg, forKey: .leg)
    try c.encodeNullable(quantity, forKey: .quantity)
    try c.encodeNullable(price, forKey: .price)
    try c.encodeNullable(stopPrice, forKey: .stopPrice)
    try c.encodeNullable(subject, forKey: .subject)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// GET /events?date=: the day's events, oldest first; empty with `cause` when the bot's database
/// is missing or unreadable.
public struct DayEventsV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let events: [DayEventV1]
  public let cause: String?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case day, events, cause
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    day = try c.decode(WireDate.self, forKey: .day)
    events = try c.decode([DayEventV1].self, forKey: .events)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(events, forKey: .events)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
