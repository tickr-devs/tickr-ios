import Foundation

// Swift mirror of the status-v1 position, its stop and the entry send record shared with trades
// (src/aperture/api/contract.py); its own file to keep Contract.swift within the file length limit.

public struct Stop: Codable, Hashable, Sendable {
  public let state: StopState
  public let price: DecimalString?
  public let clientOrderId: String?

  enum CodingKeys: String, CodingKey {
    case state, price
    case clientOrderId = "client_order_id"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    state = try c.decode(StopState.self, forKey: .state)
    price = try c.decodeNullable(DecimalString.self, forKey: .price)
    clientOrderId = try c.decodeNullable(String.self, forKey: .clientOrderId)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(price, forKey: .price)
    try c.encodeNullable(clientOrderId, forKey: .clientOrderId)
  }
}

public struct Position: Codable, Hashable, Sendable {
  public let symbol: String
  public let quantity: DecimalString
  public let entryPrice: DecimalString
  public let openedAt: WireTime
  public let stop: Stop
  /// How the entry order was sent; see `EntrySend`.
  public let entry: EntrySend
  /// Why the bot has no entry send record for the position; nil when it has one.
  public let entryCause: String?

  enum CodingKeys: String, CodingKey {
    case symbol, quantity, stop, entry
    case entryPrice = "entry_price"
    case openedAt = "opened_at"
    case entryCause = "entry_cause"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    entryPrice = try c.decode(DecimalString.self, forKey: .entryPrice)
    openedAt = try c.decode(WireTime.self, forKey: .openedAt)
    stop = try c.decode(Stop.self, forKey: .stop)
    entry = try c.decode(EntrySend.self, forKey: .entry)
    entryCause = try c.decodeNullable(String.self, forKey: .entryCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(quantity, forKey: .quantity)
    try c.encode(entryPrice, forKey: .entryPrice)
    try c.encode(openedAt, forKey: .openedAt)
    try c.encode(stop, forKey: .stop)
    try c.encode(entry, forKey: .entry)
    try c.encodeNullable(entryCause, forKey: .entryCause)
  }
}

/// The recorded outcome of the one send of an entry order.
public enum SendOutcome: String, Codable, Sendable {
  /// Recorded before the HTTP call; not sent yet.
  case intent
  /// Sent; the broker's answer did not arrive.
  case attempted
  case acknowledged
  case refused
  /// Sent, and the outcome could not be known; the broker is read, never resent.
  case unknown
  /// No send was recorded.
  case absent
}

/// The entry order of a position or trade: its intent, its one send and its fill. Every field is
/// nil when the bot did not record it; `sends` other than 1 breaks "one send per decision".
public struct EntrySend: Codable, Hashable, Sendable {
  public let clientOrderId: String?
  public let intentAt: WireTime?
  public let sentAt: WireTime?
  /// Outcome of the send as recorded when it was made.
  public let sendOutcome: SendOutcome?
  /// The send's latest state (an unknown outcome may later read acknowledged); nil exactly when
  /// `sendOutcome` is nil.
  public let latestOutcome: SendOutcome?
  public let sends: Int?
  public let filledAt: WireTime?

  enum CodingKeys: String, CodingKey {
    case sends
    case clientOrderId = "client_order_id"
    case intentAt = "intent_at"
    case sentAt = "sent_at"
    case sendOutcome = "send_outcome"
    case latestOutcome = "latest_outcome"
    case filledAt = "filled_at"
  }

  /// The entry was sent other than exactly once, as far as the record shows.
  public var sentOtherThanOnce: Bool { sends.map { $0 != 1 } ?? false }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    clientOrderId = try c.decodeNullable(String.self, forKey: .clientOrderId)
    intentAt = try c.decodeNullable(WireTime.self, forKey: .intentAt)
    sentAt = try c.decodeNullable(WireTime.self, forKey: .sentAt)
    sendOutcome = try c.decodeNullable(SendOutcome.self, forKey: .sendOutcome)
    latestOutcome = try c.decodeNullable(SendOutcome.self, forKey: .latestOutcome)
    sends = try c.decodeNullable(Int.self, forKey: .sends)
    filledAt = try c.decodeNullable(WireTime.self, forKey: .filledAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(clientOrderId, forKey: .clientOrderId)
    try c.encodeNullable(intentAt, forKey: .intentAt)
    try c.encodeNullable(sentAt, forKey: .sentAt)
    try c.encodeNullable(sendOutcome, forKey: .sendOutcome)
    try c.encodeNullable(latestOutcome, forKey: .latestOutcome)
    try c.encodeNullable(sends, forKey: .sends)
    try c.encodeNullable(filledAt, forKey: .filledAt)
  }
}
