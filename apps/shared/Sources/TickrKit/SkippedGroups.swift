import Foundation

/// Refusal codes the apps put in words: every `AdmissionCause` (src/tickr/risk/causes.py) and
/// ENGINE_REFUSED, so every code GET /skipped sends (tests/test_api_codes.py checks this). The
/// API's UNKNOWN, and a code from a newer bot, have no case: they read as "Other reason".
public enum RefusalCode: String, Sendable, CaseIterable {
  case gateClosed = "GATE_CLOSED"
  case clockInvalid = "CLOCK_INVALID"
  case notReconciled = "RECONCILIATION_NOT_DONE"
  case brokerReadMissing = "BROKER_READ_MISSING"
  case brokerReadStale = "BROKER_READ_STALE"
  case unresolvedExposure = "UNRESOLVED_EXPOSURE"
  case foreignExposure = "FOREIGN_EXPOSURE"
  case entryStop = "ENTRY_STOP_SET"
  case calendarUnknown = "CALENDAR_UNKNOWN"
  case calendarDayMismatch = "CALENDAR_DAY_MISMATCH"
  case halfDay = "HALF_DAY"
  case outsideSession = "OUTSIDE_REGULAR_SESSION"
  case beforeFirstEntry = "BEFORE_FIRST_ENTRY"
  case sessionTimesInvalid = "SESSION_TIMES_INVALID"
  case afterLastEntry = "AFTER_LAST_ENTRY"
  case countInvalid = "COUNT_INVALID"
  case ownPosition = "OWN_POSITION_OPEN"
  case ownOrder = "OWN_ORDER_WORKING"
  case positionLimit = "POSITION_LIMIT_REACHED"
  case workingEntryLimit = "WORKING_ENTRY_LIMIT_REACHED"
  case cooldown = "SYMBOL_COOLDOWN"
  case decisionNotEnter = "DECISION_NOT_ENTER"
  case decisionNotActive = "DECISION_NOT_ACTIVE"
  case strategyNotExtended = "STRATEGY_NOT_EXTENDED"
  case decisionIncomplete = "DECISION_INCOMPLETE"
  case decisionInvalid = "DECISION_INVALID"
  case orderPricesMissing = "ORDER_PRICES_MISSING"
  case orderPricesInvalid = "ORDER_PRICES_INVALID"
  case setupInvalidated = "SETUP_INVALIDATED"
  case quoteMissing = "QUOTE_MISSING"
  case quoteSymbolMismatch = "QUOTE_SYMBOL_MISMATCH"
  case quoteInvalid = "QUOTE_INVALID"
  case quoteTimeInvalid = "QUOTE_TIME_INVALID"
  case quoteStale = "QUOTE_STALE"
  case spreadTooWide = "SPREAD_TOO_WIDE"
  case priceOutside = "PRICE_OUTSIDE_WINDOW"
  case priceCollarUnknown = "PRICE_COLLAR_UNKNOWN"
  case priceCollarBreach = "PRICE_COLLAR_BREACH"
  case quantityBelowOne = "QUANTITY_BELOW_ONE"
  case quantityNotWhole = "QUANTITY_NOT_WHOLE"
  case notionalOverCap = "NOTIONAL_OVER_CAP"
  case plannedLossOver = "PLANNED_LOSS_OVER_LIMIT"
  case dailyMoneyUnknown = "DAILY_MONEY_UNKNOWN"
  case dailyMoneyInvalid = "DAILY_MONEY_INVALID"
  case dailyCeiling = "DAILY_CEILING"
  case buyingPowerUnknown = "BUYING_POWER_UNKNOWN"
  case buyingPowerShort = "BUYING_POWER_SHORT"
  /// The account equity the percent-of-equity limits need (`[risk]`, off unless configured).
  case equityUnknown = "EQUITY_UNKNOWN"
  case entryBudget = "ENTRY_BUDGET_UNAVAILABLE"
  case stopBudget = "STOP_BUDGET_UNAVAILABLE"
  case tradabilityBudget = "TRADABILITY_BUDGET_UNAVAILABLE"
  /// The broker's tradability answer (backlog T8, only with the check on in config).
  case tradabilityUnknown = "TRADABILITY_UNKNOWN"
  case instrumentHalted = "INSTRUMENT_HALTED"
  case instrumentCloseOnly = "INSTRUMENT_CLOSE_ONLY"
  case instrumentDenied = "INSTRUMENT_DENIED"
  case instrumentNotTradable = "INSTRUMENT_NOT_TRADABLE"
  /// Admission passed but the engine refused to open the trade (src/tickr/runtime/entries.py).
  case engineRefused = "ENGINE_REFUSED"

  /// SF Symbols of the refusal families: the gate, an operator pause or the engine's last check,
  /// a broker read, reconciliation or the clock, exposure the bot did not open, the session's hours
  /// and calendar, the bot's own positions and orders, a pause after a loss, the signal or its
  /// setup, the quote, the order's prices, size and loss limits, and the request budget; and of a
  /// cause this app has no words for.
  public static let gateSymbol = "lock.fill"
  public static let brokerSymbol = "arrow.triangle.2.circlepath"
  public static let exposureSymbol = "person.crop.circle.badge.questionmark"
  public static let sessionSymbol = "clock"
  public static let ownSymbol = "square.stack.fill"
  public static let cooldownSymbol = "pause.circle.fill"
  public static let setupSymbol = "xmark.circle"
  public static let quoteSymbol = "waveform.path.ecg"
  public static let priceSymbol = "arrow.up.and.down"
  public static let sizeSymbol = "scalemass.fill"
  public static let budgetSymbol = "speedometer"
  public static let unknownSymbol = "questionmark.circle"

  /// The symbol of this refusal's family, for a row or a glyph next to its words.
  public var symbol: String {
    switch self {
    case .gateClosed, .entryStop, .engineRefused: return Self.gateSymbol
    case .clockInvalid, .notReconciled, .brokerReadMissing, .brokerReadStale, .buyingPowerUnknown, .equityUnknown,
      .tradabilityUnknown, .instrumentHalted, .instrumentCloseOnly, .instrumentDenied, .instrumentNotTradable:
      return Self.brokerSymbol
    case .unresolvedExposure, .foreignExposure: return Self.exposureSymbol
    case .calendarUnknown, .calendarDayMismatch, .halfDay, .outsideSession, .beforeFirstEntry, .sessionTimesInvalid,
      .afterLastEntry, .strategyNotExtended:
      return Self.sessionSymbol
    case .countInvalid, .ownPosition, .ownOrder, .positionLimit, .workingEntryLimit: return Self.ownSymbol
    case .cooldown: return Self.cooldownSymbol
    case .decisionNotEnter, .decisionNotActive, .decisionIncomplete, .decisionInvalid, .setupInvalidated:
      return Self.setupSymbol
    case .quoteMissing, .quoteSymbolMismatch, .quoteInvalid, .quoteTimeInvalid, .quoteStale, .spreadTooWide:
      return Self.quoteSymbol
    case .orderPricesMissing, .orderPricesInvalid, .priceOutside, .priceCollarUnknown, .priceCollarBreach:
      return Self.priceSymbol
    case .quantityBelowOne, .quantityNotWhole, .notionalOverCap, .plannedLossOver, .dailyMoneyUnknown,
      .dailyMoneyInvalid, .dailyCeiling, .buyingPowerShort:
      return Self.sizeSymbol
    case .entryBudget, .stopBudget, .tradabilityBudget: return Self.budgetSymbol
    }
  }
}

/// The single recorded cause of a refused entry, "CODE: detail", as the bot writes it
/// (src/tickr/risk/admission.py).
public struct RefusalCause: Hashable, Sendable {
  /// "SYMBOL_COOLDOWN"; the whole text when it has no code.
  public let code: String
  /// What follows the code; empty when nothing does.
  public let detail: String
  /// The window the refusal covers, when the bot sent it structured (`RefusalV1`); a pause after
  /// a loss has both ends.
  public let since: Date?
  public let until: Date?
  /// The values the detail names, when the bot sent the refusal structured.
  public let params: [String: String]

  /// Between the code and the detail.
  public static let separator = ": "
  /// Punctuation that may follow a time inside a detail ("…16:26:30+00:00;").
  static let trailing: Set<Character> = [";", ",", ")", "."]

  /// `text` is "CODE: detail"; `refusal`, the same refusal structured, lends its window.
  public init(_ text: String, refusal: RefusalV1? = nil) {
    since = refusal?.since?.date
    until = refusal?.until?.date
    params = refusal?.params ?? [:]
    if let range = text.range(of: Self.separator) {
      code = String(text[..<range.lowerBound])
      detail = String(text[range.upperBound...])
    } else {
      code = text
      detail = ""
    }
  }

  /// The detail in the person's language, nil when there is no sentence for it or a value is
  /// missing.
  public var phrase: String? { ApiText.refusalDetail(code: code, params: params) }

  /// The code, when the apps know it.
  public var known: RefusalCode? { RefusalCode(rawValue: code) }

  /// Whether the text starts with a machine code ("SYMBOL_COOLDOWN") rather than being the bot's
  /// prose without one. A code is never shown to a person: one the apps do not know reads as
  /// "Other reason" followed by its detail; prose without a code is shown as written.
  public var hasCode: Bool {
    code.contains(where: \.isLetter)
      && code.allSatisfy { ($0.isLetter && $0.isUppercase) || $0.isNumber || $0 == Self.codeJoiner }
  }

  /// Joins the words of a code ("SYMBOL_COOLDOWN").
  static let codeJoiner: Character = "_"

  /// The ISO-8601 times in `detail`, in the order written.
  public var times: [Date] {
    detail.split(separator: " ").compactMap { Self.parse(Self.split($0).time) }
  }

  /// A pause after a loss: when the losing trade closed and when entries may resume.
  public var cooldown: (loss: Date, until: Date)? {
    if known == .cooldown, let since, let until { return (since, until) }
    let times = self.times
    guard known == .cooldown, let loss = times.first, let until = times.last, times.count > 1 else { return nil }
    return (loss, until)
  }

  /// `detail` with every time it holds written by `time`, such as "16:26".
  public func readable(time: (Date) -> String) -> String {
    detail.split(separator: " ", omittingEmptySubsequences: false).map { word in
      let (body, tail) = Self.split(word)
      return Self.parse(body).map { time($0) + tail } ?? String(word)
    }.joined(separator: " ")
  }

  /// A word without the punctuation that follows it, and that punctuation.
  static func split(_ word: Substring) -> (time: String, tail: String) {
    var body = word
    while let last = body.last, trailing.contains(last) { body.removeLast() }
    return (String(body), String(word[body.endIndex...]))
  }

  /// A time as Python's `isoformat()` writes it with an offset, with or without fractions.
  static func parse(_ text: String) -> Date? {
    if let date = try? Date(text, strategy: .iso8601) { return date }
    return try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
  }
}

/// Signals not taken in a row on one symbol for the same reason, listed as one row: a pause
/// after a loss refuses the same symbol every minute, and twenty identical rows say less than one.
public struct SkippedGroup: Hashable, Sendable, Identifiable {
  /// Oldest first.
  public let signals: [SkippedSignalV1]

  public var first: SkippedSignalV1 { signals[0] }
  public var latest: SkippedSignalV1 { signals[signals.count - 1] }
  public var count: Int { signals.count }
  public var id: String { "\(first.symbol) \(first.at.date.timeIntervalSince1970)" }
  /// The latest signal's cause, nil when it was not refused: its "CODE: detail" text (which holds
  /// the times), else its structured refusal as "CODE: message".
  public var cause: RefusalCause? {
    latest.refusalCause.map { RefusalCause($0, refusal: latest.refusal) }
      ?? latest.refusal.map { RefusalCause($0.code + RefusalCause.separator + $0.message, refusal: $0) }
  }

  /// `signals` as GET /skipped serves them (oldest first), grouped and listed newest first. A
  /// signal joins its symbol's previous group when it had the same admission and cause code;
  /// anything else on that symbol in between starts a new group.
  public static func make(_ signals: [SkippedSignalV1]) -> [SkippedGroup] {
    var groups: [[SkippedSignalV1]] = []
    var latestGroup: [String: Int] = [:]
    for signal in signals {
      if let index = latestGroup[signal.symbol], let last = groups[index].last, same(last, signal) {
        groups[index].append(signal)
      } else {
        groups.append([signal])
        latestGroup[signal.symbol] = groups.count - 1
      }
    }
    return groups.map(SkippedGroup.init(signals:)).sorted { $0.latest.at.date > $1.latest.at.date }
  }

  static func same(_ a: SkippedSignalV1, _ b: SkippedSignalV1) -> Bool {
    a.admission == b.admission && a.strategy == b.strategy && code(a) == code(b)
  }

  /// The refusal code: the structured refusal's, else the code that starts `refusal_cause`.
  static func code(_ signal: SkippedSignalV1) -> String? {
    signal.refusal?.code ?? signal.refusalCause.map { RefusalCause($0).code }
  }
}

/// How many signals each refusal cause refused, most first; for "why signals were refused".
public struct RefusalCount: Hashable, Sendable, Identifiable {
  /// Nil for refusals the bot recorded without a cause.
  public let cause: RefusalCause?
  public let count: Int

  public var id: String { cause?.code ?? String() }

  /// Refused `signals` counted by cause code (each signal once, not merged into runs), the most
  /// frequent first and ties by code; a refusal without a recorded cause is counted under nil,
  /// never dropped; signals that were not refused are left out.
  public static func make(_ signals: [SkippedSignalV1]) -> [RefusalCount] {
    var counts: [String?: Int] = [:]
    var first: [String: RefusalCause] = [:]
    for signal in signals where signal.admission == .refused {
      // The structured refusal when the record has one, as the grouped rows do.
      let text = signal.refusal.map { $0.code + RefusalCause.separator + $0.message } ?? signal.refusalCause
      let code = SkippedGroup.code(signal)
      counts[code, default: 0] += 1
      if let code, let text, first[code] == nil { first[code] = RefusalCause(text, refusal: signal.refusal) }
    }
    return counts.map { code, count in RefusalCount(cause: code.flatMap { first[$0] }, count: count) }
      .sorted { $0.count != $1.count ? $0.count > $1.count : $0.id < $1.id }
  }
}
