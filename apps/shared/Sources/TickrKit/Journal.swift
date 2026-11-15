import Foundation

// Swift mirror of journal-v1 (GET /journal) in src/tickr/api/contract.py: the latest rows of
// the bot's journal with their numbers. Read-only.

/// One journal row: its number, when it was written, its kind and the symbol it is about.
public struct JournalRowV1: Codable, Hashable, Sendable {
  public let seq: Int
  public let at: WireTime
  /// The bot's row kind, such as `order-intent` or `reconcile-checked`.
  public let kind: String
  /// Nil for rows about no one symbol.
  public let symbol: String?

  enum CodingKeys: String, CodingKey {
    case seq, at, kind, symbol
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    seq = try c.decode(Int.self, forKey: .seq)
    at = try c.decode(WireTime.self, forKey: .at)
    kind = try c.decode(String.self, forKey: .kind)
    symbol = try c.decodeNullable(String.self, forKey: .symbol)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(seq, forKey: .seq)
    try c.encode(at, forKey: .at)
    try c.encode(kind, forKey: .kind)
    try c.encodeNullable(symbol, forKey: .symbol)
  }
}

/// GET /journal.
public struct JournalV1: Codable, Hashable, Sendable {
  /// The newest row's number, or nil when the journal is empty or could not be read.
  public let lastSeq: Int?
  public let rows: [JournalRowV1]
  /// Why there are no rows.
  public let cause: String?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case rows, cause
    case lastSeq = "last_seq"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    lastSeq = try c.decodeNullable(Int.self, forKey: .lastSeq)
    rows = try c.decode([JournalRowV1].self, forKey: .rows)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(lastSeq, forKey: .lastSeq)
    try c.encode(rows, forKey: .rows)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
