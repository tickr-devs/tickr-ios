import Foundation

// The Symbols table of mockup v101: one column grid for every tab and every kind of row, sorted by
// a click on a column's title. The Fast movers tab lists the flagged symbols with the open
// positions and the watches pinned on top for context. Pure, so both apps sort and word it alike.

/// A column of the Symbols table, in the design's order.
public enum SymbolsColumn: String, CaseIterable, Identifiable, Hashable, Sendable {
  case symbol, last, change, volume, atr, dollars, screener, stage, outcome, time

  public var id: String { rawValue }

  /// Figures align to the right.
  public var isFigure: Bool {
    switch self {
    case .last, .change, .volume, .atr, .dollars, .time: true
    case .symbol, .screener, .stage, .outcome: false
    }
  }

  /// The first click sorts names and ranks up, figures and stages down.
  public var ascendsFirst: Bool { self == .symbol || self == .screener }

  /// The column's title; the time column reads "Flagged" on the Fast movers tab.
  public func title(fastMovers: Bool) -> LocalizedStringResource {
    switch self {
    case .symbol: L10n.symbolsColumnSymbol
    case .last: L10n.symbolsColumnLast
    case .change: L10n.symbolsColumnChange
    case .volume: L10n.symbolsColumnVolume
    case .atr: L10n.symbolsColumnAtr
    case .dollars: L10n.symbolsColumnDollars
    case .screener: L10n.symbolsColumnScreener
    case .stage: L10n.symbolsColumnStage
    case .outcome: L10n.symbolsColumnOutcome
    case .time: fastMovers ? L10n.symbolsColumnFlagged : L10n.symbolsColumnSeen
    }
  }
}

/// What the person asked the table for: the filter, the search and the order.
public struct SymbolsQuery: Hashable, Sendable {
  public var filter: SymbolsFilter
  public var search: String
  public var order: SymbolsOrder

  public init(filter: SymbolsFilter, search: String, order: SymbolsOrder) {
    self.filter = filter
    self.search = search
    self.order = order
  }
}

/// The order of the table: a column and its direction.
public struct SymbolsOrder: Hashable, Sendable {
  public var column: SymbolsColumn
  public var ascending: Bool

  public init(column: SymbolsColumn, ascending: Bool) {
    self.column = column
    self.ascending = ascending
  }

  /// A tab's order before any click: the stage reached, or on the Fast movers tab the ATR move.
  public static func standard(_ tab: SymbolsTab) -> SymbolsOrder {
    SymbolsOrder(column: tab == .fastMovers ? .atr : .stage, ascending: false)
  }

  /// After a click on `column`'s title: the other direction on the sorted column, else the
  /// column's first direction.
  public func clicked(_ column: SymbolsColumn) -> SymbolsOrder {
    column == self.column
      ? SymbolsOrder(column: column, ascending: !ascending)
      : SymbolsOrder(column: column, ascending: column.ascendsFirst)
  }
}

/// One line of the table: the symbol's row of the day, its fast mover bar, and whether it is an
/// open position. A pinned line (Fast movers tab) has a row but no bar.
/// A line's price and change as shown (`SymbolsBoard.shown`).
public struct SymbolsPrice: Hashable, Sendable {
  public let price: Decimal?
  /// Change from the previous close, in percent.
  public let changePct: Decimal?
  /// `price` is the live bid of the bot's quotes, not the screener's.
  public let isLive: Bool
}

public struct SymbolsLine: Identifiable, Hashable, Sendable {
  public let symbol: String
  public let row: SymbolRowV1?
  public let mover: FastMoverV1?
  public let position: Bool

  public init(symbol: String, row: SymbolRowV1?, mover: FastMoverV1?, position: Bool) {
    self.symbol = symbol
    self.row = row
    self.mover = mover
    self.position = position
  }

  public var id: String { symbol }

  /// The strategy's latest decision is WATCH.
  public var watching: Bool { row?.verdict == .watch || mover?.watching == true }
}

/// What a line's outcome badge says.
public enum SymbolsOutcome: Hashable, Sendable {
  case passed, waiting, dropped, notReached

  public init(_ state: SymbolState) {
    switch state {
    case .passed: self = .passed
    case .waiting: self = .waiting
    case .dropped: self = .dropped
    case .notReached: self = .notReached
    }
  }

  public var title: LocalizedStringResource {
    switch self {
    case .passed: L10n.symbolsOutcomePassed
    case .waiting: L10n.symbolsOutcomeWaiting
    case .dropped: L10n.symbolsOutcomeDropped
    case .notReached: L10n.symbolsOutcomeNotReached
    }
  }
}

extension SymbolsBoard {
  /// The lines of `tab`: on a stage tab every symbol that reached it (`rows`' filter and search),
  /// on the Fast movers tab every flagged symbol plus the positions and watches without a bar,
  /// pinned on top. In the query's order, missing values last, then furthest stage and symbol.
  /// Never capped.
  public static func lines(
    _ tab: SymbolsTab, symbols: SymbolsV1?, movers: MoversV1?, positions: Set<String>, query: SymbolsQuery
  ) -> [SymbolsLine] {
    let (filter, search, order) = (query.filter, query.search, query.order)
    let rows = symbols?.rows ?? []
    let rowOf = Dictionary(rows.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
    let moverOf = Dictionary((movers?.movers ?? []).map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
    let lines: [SymbolsLine]
    switch tab {
    case .stage(let stage):
      lines = self.rows(rows, stage: stage, filter: filter, sort: .symbol, search: search).map {
        SymbolsLine(symbol: $0.symbol, row: $0, mover: moverOf[$0.symbol], position: positions.contains($0.symbol))
      }
    case .fastMovers:
      let flagged = self.movers(movers?.movers ?? [], search: search).map {
        SymbolsLine(symbol: $0.symbol, row: rowOf[$0.symbol], mover: $0, position: positions.contains($0.symbol))
      }
      let query = search.trimmingCharacters(in: .whitespaces).uppercased()
      let pinned = rows.filter { row in
        moverOf[row.symbol] == nil && (positions.contains(row.symbol) || row.verdict == .watch)
          && (query.isEmpty || row.symbol.uppercased().contains(query))
      }.map { SymbolsLine(symbol: $0.symbol, row: $0, mover: nil, position: positions.contains($0.symbol)) }
      return sorted(pinned, order, fastMovers: true) + sorted(flagged, order, fastMovers: true)
    }
    return sorted(lines, order, fastMovers: false)
  }

  static func sorted(_ lines: [SymbolsLine], _ order: SymbolsOrder, fastMovers: Bool) -> [SymbolsLine] {
    lines.sorted { a, b in
      let key = compare(a, b, order.column, fastMovers: fastMovers)
      if let key, key != .orderedSame {
        return order.ascending ? key == .orderedAscending : key == .orderedDescending
      }
      if key == nil { return value(a, order.column, fastMovers) != nil }  // missing values last
      let reachA = a.row?.furthest.order ?? 0
      let reachB = b.row?.furthest.order ?? 0
      return reachA != reachB ? reachA > reachB : a.symbol < b.symbol
    }
  }

  /// How two lines compare on `column`; nil when one of them has no value there.
  private static func compare(
    _ a: SymbolsLine, _ b: SymbolsLine, _ column: SymbolsColumn, fastMovers: Bool
  ) -> ComparisonResult? {
    if column == .symbol { return a.symbol.compare(b.symbol) }
    guard let x = value(a, column, fastMovers), let y = value(b, column, fastMovers) else {
      return value(a, column, fastMovers) == nil && value(b, column, fastMovers) == nil ? .orderedSame : nil
    }
    return x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame
  }

  /// The number a column sorts by; nil when the line has none.
  private static func value(_ line: SymbolsLine, _ column: SymbolsColumn, _ fastMovers: Bool) -> Decimal? {
    switch column {
    case .symbol: return nil
    case .last: return price(line)?.value
    case .change: return line.row?.changePct?.value
    case .volume: return line.mover?.volumeRatio.value
    case .atr: return line.mover.map { abs($0.moveAtr.value) }
    case .dollars: return line.mover?.dollarVolumeRatio.value
    case .screener: return line.row.flatMap(bestRank).map { Decimal($0) }
    case .stage: return line.row.map(stageKey)
    case .outcome: return line.row.map { Decimal(outcomeOrder.firstIndex(of: $0.state) ?? 0) }
    case .time:
      let date = fastMovers ? line.mover?.at.date : line.row?.firstSeen?.date
      return date.map { Decimal($0.timeIntervalSince1970) }
    }
  }

  /// The stage column's key: the furthest stage, and within it a symbol dropped there below one
  /// that stands there otherwise.
  private static func stageKey(_ row: SymbolRowV1) -> Decimal {
    Decimal(row.furthest.order * outcomeOrder.count + (row.state == .dropped ? 0 : 1))
  }

  /// Outcomes from worst to best, as the outcome column sorts them.
  private static let outcomeOrder: [SymbolState] = [.dropped, .notReached, .waiting, .passed]

  // MARK: cells

  /// The line's last price: the screener row's, else the fast bar's close.
  public static func price(_ line: SymbolsLine) -> DecimalString? { line.row?.price ?? line.mover?.close }

  /// What a line shows as its price and change: the live bid of the bot's quotes where it holds
  /// one for the symbol (the symbol is on its stream), with the change from the previous close the
  /// screener row implies; else the screener's price and change, as of its last pass.
  public static func shown(_ line: SymbolsLine, live: LivePrice?) -> SymbolsPrice {
    let screener = SymbolsPrice(price: price(line)?.value, changePct: line.row?.changePct?.value, isLive: false)
    guard let live else { return screener }
    let previous = SymbolDayLine.previousClose(price: price(line), changePct: line.row?.changePct)
    let change = previous.flatMap { $0 > 0 ? (live.bid - $0) / $0 * SymbolDayLine.percent : nil }
    return SymbolsPrice(price: live.bid, changePct: change, isLive: true)
  }

  /// "▲ 18.20%", "▼ 4.20%": the change from the previous close; nil without one.
  public static func tableChange(_ value: DecimalString?) -> String? {
    tableChange(value?.value)
  }

  /// "▲ 18.20%", "▼ 4.20%": the change from the previous close; nil without one.
  public static func tableChange(_ value: Decimal?) -> String? {
    guard let value else { return nil }
    let body = fixed(abs(value), digits: tableChangeDigits)
    return String(localized: value < 0 ? L10n.symbolsChangeDown(body) : L10n.symbolsChangeUp(body))
  }

  /// "6.4×": a ratio cell of the table.
  public static func ratio(_ value: DecimalString) -> String {
    String(localized: L10n.symbolsRatio(fixed(value.value, digits: ratioDigits)))
  }

  /// "+2.1", "−2.6": the ATR cell of the table.
  public static func atr(_ value: DecimalString) -> String {
    let body = fixed(abs(value.value), digits: ratioDigits)
    return (value.value < 0 ? minus : value.value > 0 ? plus : "") + body
  }

  /// The best-ranked screener as "Gainers #3", and how many others listed it ("+1"); nil without.
  public static func screenerCell(_ row: SymbolRowV1?) -> (chip: String, more: String?)? {
    guard let row, let best = row.sources.min(by: { $0.rank < $1.rank }) else { return nil }
    let more = row.sources.count - 1
    return (source(best), more > 0 ? String(localized: L10n.symbolsMore(more)) : nil)
  }

  /// A screener's full name with the rank, for the detail ("Top gainers", "#3").
  public static func screenerName(_ source: SymbolSourceV1) -> String {
    String(localized: source.kind.fullTitle)
  }

  /// The words after a line's outcome badge: what was measured against what for a drop or a
  /// stop before a decision; for a waiting symbol the check it waits on; nothing when it passed.
  public static func why(_ row: SymbolRowV1) -> String? {
    switch row.state {
    case .dropped, .notReached: return reason(row)
    case .waiting: return row.checks.first { !$0.passed }.map(checkText) ?? outcome(row).detail
    case .passed: return nil
    }
  }

  /// "met ≥ 5.0×" or "< 5.0×": a fast mover figure against its threshold, for the detail.
  public static func moverNote(fired: Bool, threshold: DecimalString, ratio: Bool) -> String {
    let value = fixed(threshold.value, digits: ratioDigits)
    let shown = ratio ? String(localized: L10n.symbolsRatio(value)) : value
    return String(localized: fired ? L10n.symbolsMoverMet(shown) : L10n.symbolsMoverUnmet(shown))
  }

  /// Decimals of a change in the table ("▲ 18.20%", mockup v101).
  public static let tableChangeDigits = 2
  /// The typographic minus of a negative figure.
  static let minus = "\u{2212}"
}

extension ScreenerSource {
  /// The screener's full name, as the detail lists it.
  public var fullTitle: LocalizedStringResource {
    switch self {
    case .gainers: L10n.symbolsScreenerGainers
    case .losers: L10n.symbolsScreenerLosers
    case .topActives: L10n.symbolsScreenerActives
    }
  }
}

/// The words of the Symbols table and detail that both apps show (mockup v101).
public enum SymbolsText {
  public static var position: LocalizedStringResource { L10n.symbolsPosition }
  public static func seen(_ time: String) -> LocalizedStringResource { L10n.symbolsSeen(time) }
  public static var today: LocalizedStringResource { L10n.symbolsToday }
  public static func atStage(_ stage: String) -> LocalizedStringResource { L10n.symbolsAtStage(stage) }
  public static func reachedStage(_ stage: String) -> LocalizedStringResource { L10n.symbolsReachedStage(stage) }
  public static var fastMover: LocalizedStringResource { L10n.symbolsFastMover }
  public static func flagged(_ time: String) -> LocalizedStringResource { L10n.symbolsFlagged(time) }
  public static var notFlagged: LocalizedStringResource { L10n.symbolsNotFlagged }
  public static var statVolume: LocalizedStringResource { L10n.symbolsStatVolume }
  public static var statMove: LocalizedStringResource { L10n.symbolsStatMove }
  public static var statDollars: LocalizedStringResource { L10n.symbolsStatDollars }
  public static var screeners: LocalizedStringResource { L10n.symbolsScreeners }
  public static func rank(_ rank: Int) -> LocalizedStringResource { L10n.symbolsRank(rank) }
  public static var lastDecision: LocalizedStringResource { L10n.symbolsLastDecision }
  public static func decided(_ time: String, _ strategy: String) -> LocalizedStringResource {
    L10n.symbolsDecided(time, strategy)
  }
  public static var noDecision: LocalizedStringResource { L10n.symbolsNoDecision }
  public static var stepNotReached: LocalizedStringResource { L10n.symbolsStepNotReached }
  public static var sortHint: LocalizedStringResource { L10n.symbolsSortHint }
  public static func filterCount(_ filter: SymbolsFilter, _ count: Int) -> LocalizedStringResource {
    L10n.symbolsFilterCount(String(localized: filter.title), count)
  }
}
