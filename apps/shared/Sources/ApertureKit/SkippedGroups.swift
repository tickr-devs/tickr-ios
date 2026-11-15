import Foundation

/// Refusal codes the apps put in words (src/aperture/risk/causes.py, AdmissionCause). The bot
/// has more; a code not listed here is shown as the bot wrote it.
public enum RefusalCode: String, Sendable, CaseIterable {
  case gateClosed = "GATE_CLOSED"
  case notReconciled = "RECONCILIATION_NOT_DONE"
  case brokerReadMissing = "BROKER_READ_MISSING"
  case brokerReadStale = "BROKER_READ_STALE"
  case unresolvedExposure = "UNRESOLVED_EXPOSURE"
  case foreignExposure = "FOREIGN_EXPOSURE"
  case entryStop = "ENTRY_STOP_SET"
  case halfDay = "HALF_DAY"
  case outsideSession = "OUTSIDE_REGULAR_SESSION"
  case afterLastEntry = "AFTER_LAST_ENTRY"
  case ownPosition = "OWN_POSITION_OPEN"
  case ownOrder = "OWN_ORDER_WORKING"
  case positionLimit = "POSITION_LIMIT_REACHED"
  case cooldown = "SYMBOL_COOLDOWN"
  case setupInvalidated = "SETUP_INVALIDATED"
  case quoteMissing = "QUOTE_MISSING"
  case quoteStale = "QUOTE_STALE"
  case priceOutside = "PRICE_OUTSIDE_WINDOW"
  case quantityBelowOne = "QUANTITY_BELOW_ONE"
  case notionalOverCap = "NOTIONAL_OVER_CAP"
  case plannedLossOver = "PLANNED_LOSS_OVER_LIMIT"
  case dailyCeiling = "DAILY_CEILING"
  case entryBudget = "ENTRY_BUDGET_UNAVAILABLE"
  case stopBudget = "STOP_BUDGET_UNAVAILABLE"
}

/// The single recorded cause of a refused entry, "CODE: detail", as the bot writes it
/// (src/aperture/risk/admission.py).
public struct RefusalCause: Hashable, Sendable {
  /// "SYMBOL_COOLDOWN"; the whole text when it has no code.
  public let code: String
  /// What follows the code; empty when nothing does.
  public let detail: String

  /// Between the code and the detail.
  public static let separator = ": "
  /// Punctuation that may follow a time inside a detail ("…16:26:30+00:00;").
  static let trailing: Set<Character> = [";", ",", ")", "."]

  public init(_ text: String) {
    if let range = text.range(of: Self.separator) {
      code = String(text[..<range.lowerBound])
      detail = String(text[range.upperBound...])
    } else {
      code = text
      detail = ""
    }
  }

  /// The code, when the apps know it.
  public var known: RefusalCode? { RefusalCode(rawValue: code) }

  /// The ISO-8601 times in `detail`, in the order written.
  public var times: [Date] {
    detail.split(separator: " ").compactMap { Self.parse(Self.split($0).time) }
  }

  /// A pause after a loss: when the losing trade closed and when entries may resume.
  public var cooldown: (loss: Date, until: Date)? {
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
  /// The latest signal's cause, nil when it was not refused.
  public var cause: RefusalCause? { latest.refusalCause.map(RefusalCause.init) }

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
    a.admission == b.admission && a.strategy == b.strategy
      && a.refusalCause.map { RefusalCause($0).code } == b.refusalCause.map { RefusalCause($0).code }
  }
}

/// How many signals each refusal cause refused, most first; for "why signals were refused".
public struct RefusalCount: Hashable, Sendable, Identifiable {
  public let cause: RefusalCause
  public let count: Int

  public var id: String { cause.code }

  /// Refused `signals` counted by cause code (each signal once, not merged into runs), the most
  /// frequent first and ties by code; signals that were not refused are left out.
  public static func make(_ signals: [SkippedSignalV1]) -> [RefusalCount] {
    var counts: [String: Int] = [:]
    var first: [String: RefusalCause] = [:]
    for signal in signals where signal.admission == .refused {
      guard let text = signal.refusalCause else { continue }
      let cause = RefusalCause(text)
      counts[cause.code, default: 0] += 1
      if first[cause.code] == nil { first[cause.code] = cause }
    }
    return counts.compactMap { code, count in first[code].map { RefusalCount(cause: $0, count: count) } }
      .sorted { $0.count != $1.count ? $0.count > $1.count : $0.cause.code < $1.cause.code }
  }
}
