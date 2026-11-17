import Foundation

// Swift mirror of GET /quotes (src/tickr/api/contract.py: LiveQuote, QuotesV1, QuotesResponseV1).

/// The newest L1 quote of one symbol on the bot's quote stream. Display only.
public struct LiveQuoteV1: Codable, Hashable, Sendable {
  public let symbol: String
  public let bid: DecimalString
  public let ask: DecimalString
  /// The provider's time of the quote.
  public let quotedAt: WireTime
  /// When the bot received it.
  public let receivedAt: WireTime

  enum CodingKeys: String, CodingKey {
    case symbol, bid, ask
    case quotedAt = "quoted_at"
    case receivedAt = "received_at"
  }
}

/// The bot's quotes file: the newest valid quote of every symbol on its stream, rewritten when
/// one changes (so its own age says nothing; each quote's `quotedAt` does).
public struct QuotesV1: Codable, Hashable, Sendable {
  public let writtenAt: WireTime
  public let quotes: [LiveQuoteV1]
  public let schemaVersion: Int

  enum CodingKeys: String, CodingKey {
    case quotes
    case writtenAt = "written_at"
    case schemaVersion = "schema_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try c.decodeVersion(forKey: .schemaVersion, expected: Wire.quotesSchemaVersion)
    writtenAt = try c.decode(WireTime.self, forKey: .writtenAt)
    quotes = try c.decode([LiveQuoteV1].self, forKey: .quotes)
  }
}

/// GET /quotes.
public struct QuotesResponseV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let quotes: QuotesV1
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case quotes
    case servedAt = "served_at"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    quotes = try c.decode(QuotesV1.self, forKey: .quotes)
  }
}
