import Foundation

public struct DaySummary: Codable, Hashable, Sendable, Identifiable {
  public let day: WireDate
  public let trades: Int
  public let wins: Int
  public let losses: Int
  public let resultGrossUsd: DecimalString
  public let hasBars: Bool
  /// Whether the day was clean by the journal: no mismatch, unknown outcome, unprotected position
  /// or safety exit, and a clean day end.
  public let clean: CleanDay
  /// The day's result after fees (the sum of its trades' `resultNetUsd`); nil while any of them
  /// is nil. Added after version 1 shipped.
  public let resultNetUsd: DecimalString?
  /// The day's market session by the bot's calendar, as sent ("regular", "half", "none"); nil
  /// when the calendar does not cover the day, or from an older bot (added with tickr-bot#21).
  public var sessionCode: String?
  /// Whether the bot sent `session`, so it round-trips.
  var sessionSent = false

  /// The day's session; nil when unknown, or a value this app does not know (never guessed).
  public var session: DaySession? { sessionCode.flatMap(DaySession.init(rawValue:)) }

  /// The result as shown: after fees once known, else the gross from the order rows.
  public var resultUsd: DecimalString { resultNetUsd ?? resultGrossUsd }

  public var id: WireDate { day }

  enum CodingKeys: String, CodingKey {
    case day, trades, wins, losses, clean
    case resultGrossUsd = "result_gross_usd"
    case hasBars = "has_bars"
    case resultNetUsd = "result_net_usd"
    case session
  }
}

// In an extension so the memberwise initializer stays available.
extension DaySummary {
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    day = try c.decode(WireDate.self, forKey: .day)
    trades = try c.decode(Int.self, forKey: .trades)
    wins = try c.decode(Int.self, forKey: .wins)
    losses = try c.decode(Int.self, forKey: .losses)
    resultGrossUsd = try c.decode(DecimalString.self, forKey: .resultGrossUsd)
    hasBars = try c.decode(Bool.self, forKey: .hasBars)
    clean = try c.decode(CleanDay.self, forKey: .clean)
    // Added after version 1 shipped: an older days document has no such key.
    resultNetUsd = try c.decodeIfPresent(DecimalString.self, forKey: .resultNetUsd)
    sessionSent = c.contains(.session)
    sessionCode = try c.decodeIfPresent(String.self, forKey: .session)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(day, forKey: .day)
    try c.encode(trades, forKey: .trades)
    try c.encode(wins, forKey: .wins)
    try c.encode(losses, forKey: .losses)
    try c.encode(resultGrossUsd, forKey: .resultGrossUsd)
    try c.encode(hasBars, forKey: .hasBars)
    try c.encode(clean, forKey: .clean)
    try c.encodeNullable(resultNetUsd, forKey: .resultNetUsd)
    if sessionSent { try c.encodeNullable(sessionCode, forKey: .session) }
  }
}

/// A recorded day's market session by the bot's trading calendar (`DaySummary.session`).
public enum DaySession: String, Sendable {
  case regular, half
  /// No session: a weekend or a market holiday.
  case closed = "none"
}
