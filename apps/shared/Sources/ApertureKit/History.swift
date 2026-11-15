import Foundation

// Swift mirror of the read-only history documents in src/aperture/api/contract.py:
// days-v1 (GET /days), day-v1 (GET /days/<date>), bars-v1 (GET /bars?symbol=&date=).

/// A New York trading date kept exactly as written on the wire ("2026-11-16").
public struct WireDate: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
  public let text: String
  public let year: Int
  public let month: Int
  public let day: Int

  static let pattern = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
  /// Parts of "YYYY-MM-DD".
  static let partCount = 3
  /// Valid month and day numbers.
  static let months = 1...12
  static let days = 1...31
  /// Hour of the day used as a safe anchor (noon: never near a DST change).
  static let anchorHour = 12
  /// How a date is written on the wire, and the time zone of trading dates.
  static let format = "%04d-%02d-%02d"
  static let newYorkZone = "America/New_York"

  public init(_ text: String) throws {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    guard Wire.matches(Self.pattern, text), parts.count == Self.partCount,
      Self.months.contains(parts[1]), Self.days.contains(parts[2]) else {
      throw ContractError(String(localized: L10n.badDate(text)))
    }
    self.text = text
    year = parts[0]
    month = parts[1]
    day = parts[2]
  }

  /// The New York date of `date`.
  public init(newYorkDateOf date: Date) {
    let parts = WireDate.newYork.dateComponents([.year, .month, .day], from: date)
    // A Gregorian calendar always fills the components it is asked for; no fallback date.
    guard let year = parts.year, let month = parts.month, let day = parts.day else {
      preconditionFailure()
    }
    self.year = year
    self.month = month
    self.day = day
    text = String(format: Self.format, year, month, day)
  }

  public static let newYork: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: WireDate.newYorkZone)!
    return calendar
  }()

  /// Noon in New York on this date: a safe anchor for formatting and calendar arithmetic.
  public var noonInNewYork: Date {
    WireDate.newYork.date(from: DateComponents(year: year, month: month, day: day, hour: Self.anchorHour))!
  }

  /// The New York date `days` calendar days later (earlier when negative).
  public func adding(days: Int) -> WireDate {
    // A Gregorian calendar always adds whole days to a noon anchor; no fallback date.
    guard let date = WireDate.newYork.date(byAdding: .day, value: days, to: noonInNewYork) else {
      preconditionFailure()
    }
    return WireDate(newYorkDateOf: date)
  }

  public var description: String { text }
  public static func < (a: WireDate, b: WireDate) -> Bool { a.text < b.text }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard let text = try? container.decode(String.self) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: String(localized: L10n.expectedDate))
    }
    do { try self.init(text) } catch {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(error)")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}

/// A closed trade with fills. 1 R = `plannedLossUsd`.
public struct DayTrade: Codable, Hashable, Sendable, Identifiable {
  public let tradeId: String
  public let symbol: String
  public let quantity: DecimalString
  public let entryPrice: DecimalString
  public let exitPrice: DecimalString
  public let openedAt: WireTime
  public let closedAt: WireTime
  public let exitReason: String
  public let stopPrice: DecimalString?
  public let plannedLossUsd: DecimalString
  public let resultGrossUsd: DecimalString
  /// Seconds from the entry fill to the broker confirming the stop; nil when not recorded.
  public let stopConfirmedAfterSeconds: DecimalString?
  /// Worst and best open result while the trade was open (maximum adverse and favourable
  /// excursion), in USD; nil when the bars to compute them were not captured.
  public let maeUsd: DecimalString?
  public let mfeUsd: DecimalString?
  /// How the entry order was sent; see `EntrySend`.
  public let entry: EntrySend
  /// Why the bot has no entry send record for the trade; nil when it has one.
  public let entryCause: String?

  public var id: String { tradeId }

  enum CodingKeys: String, CodingKey {
    case symbol, quantity
    case tradeId = "trade_id"
    case entryPrice = "entry_price"
    case exitPrice = "exit_price"
    case openedAt = "opened_at"
    case closedAt = "closed_at"
    case exitReason = "exit_reason"
    case stopPrice = "stop_price"
    case plannedLossUsd = "planned_loss_usd"
    case resultGrossUsd = "result_gross_usd"
    case stopConfirmedAfterSeconds = "stop_confirmed_after_seconds"
    case maeUsd = "mae_usd"
    case mfeUsd = "mfe_usd"
    case entry
    case entryCause = "entry_cause"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    tradeId = try c.decode(String.self, forKey: .tradeId)
    symbol = try c.decode(String.self, forKey: .symbol)
    quantity = try c.decode(DecimalString.self, forKey: .quantity)
    entryPrice = try c.decode(DecimalString.self, forKey: .entryPrice)
    exitPrice = try c.decode(DecimalString.self, forKey: .exitPrice)
    openedAt = try c.decode(WireTime.self, forKey: .openedAt)
    closedAt = try c.decode(WireTime.self, forKey: .closedAt)
    exitReason = try c.decode(String.self, forKey: .exitReason)
    stopPrice = try c.decodeNullable(DecimalString.self, forKey: .stopPrice)
    plannedLossUsd = try c.decode(DecimalString.self, forKey: .plannedLossUsd)
    resultGrossUsd = try c.decode(DecimalString.self, forKey: .resultGrossUsd)
    stopConfirmedAfterSeconds = try c.decodeNullable(DecimalString.self, forKey: .stopConfirmedAfterSeconds)
    maeUsd = try c.decodeNullable(DecimalString.self, forKey: .maeUsd)
    mfeUsd = try c.decodeNullable(DecimalString.self, forKey: .mfeUsd)
    entry = try c.decode(EntrySend.self, forKey: .entry)
    entryCause = try c.decodeNullable(String.self, forKey: .entryCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(tradeId, forKey: .tradeId)
    try c.encode(symbol, forKey: .symbol)
    try c.encode(quantity, forKey: .quantity)
    try c.encode(entryPrice, forKey: .entryPrice)
    try c.encode(exitPrice, forKey: .exitPrice)
    try c.encode(openedAt, forKey: .openedAt)
    try c.encode(closedAt, forKey: .closedAt)
    try c.encode(exitReason, forKey: .exitReason)
    try c.encodeNullable(stopPrice, forKey: .stopPrice)
    try c.encode(plannedLossUsd, forKey: .plannedLossUsd)
    try c.encode(resultGrossUsd, forKey: .resultGrossUsd)
    try c.encodeNullable(stopConfirmedAfterSeconds, forKey: .stopConfirmedAfterSeconds)
    try c.encodeNullable(maeUsd, forKey: .maeUsd)
    try c.encodeNullable(mfeUsd, forKey: .mfeUsd)
    try c.encode(entry, forKey: .entry)
    try c.encodeNullable(entryCause, forKey: .entryCause)
  }

  /// Result in R (result / planned loss), nil when the planned loss is zero.
  public var resultR: Decimal? {
    let planned = plannedLossUsd.value
    return planned == 0 ? nil : resultGrossUsd.value / planned
  }
}

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

  public var id: WireDate { day }

  enum CodingKeys: String, CodingKey {
    case day, trades, wins, losses, clean
    case resultGrossUsd = "result_gross_usd"
    case hasBars = "has_bars"
  }
}

/// The clean-day verdict of one date.
public enum CleanVerdict: String, Codable, Sendable {
  case clean
  case notClean = "not_clean"
  /// The journal cannot tell yet (the day is not over) or at all; `CleanDay.cause` says why.
  case unknown
}

/// What made a day not clean.
public enum CleanCauseKind: String, Codable, Sendable {
  case reconcileMismatch = "reconcile_mismatch"
  case unknownOrderOutcome = "unknown_order_outcome"
  case unprotectedPosition = "unprotected_position"
  case safetyExit = "safety_exit"
  case dayEndNotClean = "day_end_not_clean"
}

/// One reason a day was not clean, with the journal entries that show it.
public struct CleanCause: Codable, Hashable, Sendable {
  public let kind: CleanCauseKind
  public let text: String
  public let journalSeqs: [Int]

  enum CodingKeys: String, CodingKey {
    case kind, text
    case journalSeqs = "journal_seqs"
  }
}

/// A date's clean-day verdict and the reconciliation it rests on.
public struct CleanDay: Codable, Hashable, Sendable {
  public let verdict: CleanVerdict
  /// Why the verdict is unknown; nil otherwise.
  public let cause: String?
  /// Every reason the day was not clean; empty unless `verdict` is `notClean`.
  public let causes: [CleanCause]
  /// Reconciliation passes recorded on the date.
  public let reconcileRows: Int
  public let firstReconcileAt: WireTime?
  public let lastReconcileAt: WireTime?
  /// Journal entry of the day-end record; nil when there is none.
  public let dayEndSeq: Int?

  enum CodingKeys: String, CodingKey {
    case verdict, cause, causes
    case reconcileRows = "reconcile_rows"
    case firstReconcileAt = "first_reconcile_at"
    case lastReconcileAt = "last_reconcile_at"
    case dayEndSeq = "day_end_seq"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    verdict = try c.decode(CleanVerdict.self, forKey: .verdict)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    causes = try c.decode([CleanCause].self, forKey: .causes)
    reconcileRows = try c.decode(Int.self, forKey: .reconcileRows)
    firstReconcileAt = try c.decodeNullable(WireTime.self, forKey: .firstReconcileAt)
    lastReconcileAt = try c.decodeNullable(WireTime.self, forKey: .lastReconcileAt)
    dayEndSeq = try c.decodeNullable(Int.self, forKey: .dayEndSeq)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(verdict, forKey: .verdict)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encode(causes, forKey: .causes)
    try c.encode(reconcileRows, forKey: .reconcileRows)
    try c.encodeNullable(firstReconcileAt, forKey: .firstReconcileAt)
    try c.encodeNullable(lastReconcileAt, forKey: .lastReconcileAt)
    try c.encodeNullable(dayEndSeq, forKey: .dayEndSeq)
  }
}

/// GET /days: every New York date with records, newest first.
public struct DaysV1: Codable, Hashable, Sendable {
  public let environment: String
  public let days: [DaySummary]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, days
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    days = try c.decode([DaySummary].self, forKey: .days)
  }
}

/// GET /days/<date>: trades closed that date and the symbols with captured M1 bars.
public struct DayV1: Codable, Hashable, Sendable {
  public let environment: String
  public let day: WireDate
  public let trades: [DayTrade]
  public let resultGrossUsd: DecimalString
  public let barSymbols: [String]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, day, trades
    case resultGrossUsd = "result_gross_usd"
    case barSymbols = "bar_symbols"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    day = try c.decode(WireDate.self, forKey: .day)
    trades = try c.decode([DayTrade].self, forKey: .trades)
    resultGrossUsd = try c.decode(DecimalString.self, forKey: .resultGrossUsd)
    barSymbols = try c.decode([String].self, forKey: .barSymbols)
  }
}

/// One M1 bar; `start` is the bar's opening time.
public struct BarV1: Codable, Hashable, Sendable {
  public let start: WireTime
  public let open: DecimalString
  public let high: DecimalString
  public let low: DecimalString
  public let close: DecimalString
  public let volume: DecimalString
}

/// GET /bars?symbol=&date=: captured M1 bars of one symbol on one date, oldest first.
public struct BarsV1: Codable, Hashable, Sendable {
  public let environment: String
  public let symbol: String
  public let day: WireDate
  public let bars: [BarV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, symbol, day, bars
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    symbol = try c.decode(String.self, forKey: .symbol)
    day = try c.decode(WireDate.self, forKey: .day)
    bars = try c.decode([BarV1].self, forKey: .bars)
  }
}
