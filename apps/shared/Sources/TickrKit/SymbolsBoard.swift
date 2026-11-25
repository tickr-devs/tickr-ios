import Foundation

// The Symbols screen behind the Overview funnel (GET /symbols, GET /movers): every symbol of the
// day by the stage it reached, filtered, sorted and searched, and its outcome in words. One pure
// model both apps render, so the Mac and the iPhone never disagree.

extension SymbolStage {
  /// The stage's name, as the funnel names it.
  public var title: LocalizedStringResource {
    switch self {
    case .screeners: L10n.symbolStageScreeners
    case .universe: L10n.symbolStageUniverse
    case .quote: L10n.symbolStageQuote
    case .bars: L10n.symbolStageBars
    case .strategy: L10n.symbolStageStrategy
    case .risk: L10n.symbolStageRisk
    case .order: L10n.symbolStageOrder
    case .stop: L10n.symbolStageStop
    }
  }

  /// Position in the pipeline: 0 for screeners.
  public var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// A tab of the Symbols screen: the symbols that reached one stage, or the fast movers.
public enum SymbolsTab: Hashable, Sendable, Identifiable {
  case stage(SymbolStage)
  case fastMovers

  /// Every tab in the screen's order: the eight stages, then the fast movers.
  public static let all: [SymbolsTab] = SymbolStage.allCases.map { .stage($0) } + [.fastMovers]

  public var id: String {
    switch self {
    case .stage(let stage): stage.rawValue
    case .fastMovers: Self.fastMoversID
    }
  }

  /// `id` of the fast movers tab (an identifier, never shown).
  static let fastMoversID = "fast_movers"

  public var title: LocalizedStringResource {
    switch self {
    case .stage(let stage): stage.title
    case .fastMovers: L10n.symbolsFastMovers
    }
  }

  /// The tab a funnel stage opens; nil for a stage without symbols (reconcile).
  public init?(_ stage: PipelineStage) {
    guard let symbolStage = SymbolStage(rawValue: stage.rawValue) else { return nil }
    self = .stage(symbolStage)
  }
}

/// Which rows of a stage tab show.
public enum SymbolsFilter: String, Hashable, Sendable, CaseIterable, Identifiable {
  /// Every symbol that reached the stage.
  case all
  /// The ones that went on past it.
  case passed
  /// The ones the stage dropped.
  case droppedHere

  public var id: String { rawValue }

  public var title: LocalizedStringResource {
    switch self {
    case .all: L10n.symbolsFilterAll
    case .passed: L10n.symbolsFilterPassed
    case .droppedHere: L10n.symbolsFilterDropped
    }
  }
}

/// The order of the rows.
public enum SymbolsSort: String, Hashable, Sendable, CaseIterable, Identifiable {
  /// Furthest stage first, then by symbol.
  case furthest
  case symbol
  /// Best screener rank first; symbols without a rank last.
  case rank
  /// Biggest change first; symbols without a change last.
  case change

  public var id: String { rawValue }

  public var title: LocalizedStringResource {
    switch self {
    case .furthest: L10n.symbolsSortFurthest
    case .symbol: L10n.symbolsSortSymbol
    case .rank: L10n.symbolsSortRank
    case .change: L10n.symbolsSortChange
    }
  }
}

public enum SymbolsBoard {
  /// How many symbols a tab holds: those that reached its stage (the API's own count), or the
  /// fast movers; nil before the documents are read.
  public static func count(_ tab: SymbolsTab, symbols: SymbolsV1?, movers: MoversV1?) -> Int? {
    switch tab {
    case .stage(let stage): symbols?.stages.first { $0.stage == stage }?.count
    case .fastMovers: movers?.movers.count
    }
  }

  /// The rows of a stage tab: every symbol that reached `stage`, narrowed by `filter` and
  /// `search` (a part of the symbol, any case), in `sort` order. Never capped.
  public static func rows(
    _ rows: [SymbolRowV1], stage: SymbolStage, filter: SymbolsFilter, sort: SymbolsSort, search: String = ""
  ) -> [SymbolRowV1] {
    let query = search.trimmingCharacters(in: .whitespaces).uppercased()
    let shown = rows.filter { row in
      guard row.furthest.order >= stage.order else { return false }
      guard query.isEmpty || row.symbol.uppercased().contains(query) else { return false }
      switch filter {
      case .all: return true
      case .passed: return passed(row, stage)
      case .droppedHere: return row.stage == stage && row.state == .dropped
      }
    }
    return sorted(shown, by: sort)
  }

  /// The row went on past `stage`: it reached a later one, or it is through the last.
  public static func passed(_ row: SymbolRowV1, _ stage: SymbolStage) -> Bool {
    row.furthest.order > stage.order || (row.stage == stage && row.state == .passed)
  }

  public static func sorted(_ rows: [SymbolRowV1], by sort: SymbolsSort) -> [SymbolRowV1] {
    rows.sorted { a, b in
      switch sort {
      case .symbol:
        return a.symbol < b.symbol
      case .furthest:
        return a.furthest.order != b.furthest.order ? a.furthest.order > b.furthest.order : a.symbol < b.symbol
      case .rank:
        return ordered(bestRank(a), bestRank(b), ascending: true) ?? (a.symbol < b.symbol)
      case .change:
        return ordered(a.changePct?.value, b.changePct?.value, ascending: false) ?? (a.symbol < b.symbol)
      }
    }
  }

  /// The best (lowest) rank any screener gave the row; nil without one.
  public static func bestRank(_ row: SymbolRowV1) -> Int? { row.sources.map(\.rank).min() }

  /// Comparison of two optional keys, missing ones last; nil when equal (the caller breaks ties).
  private static func ordered<T: Comparable>(_ a: T?, _ b: T?, ascending: Bool) -> Bool? {
    switch (a, b) {
    case let (a?, b?) where a != b: return ascending ? a < b : a > b
    case (.some, nil): return true
    case (nil, .some): return false
    default: return nil
    }
  }

  /// The fast movers a search leaves, in the API's order (newest bar first).
  public static func movers(_ movers: [FastMoverV1], search: String = "") -> [FastMoverV1] {
    let query = search.trimmingCharacters(in: .whitespaces).uppercased()
    return query.isEmpty ? movers : movers.filter { $0.symbol.uppercased().contains(query) }
  }

  // MARK: words

  /// How the row's outcome is drawn.
  public enum Tone: Hashable, Sendable {
    case passed, waiting, dropped, notReached
  }

  /// The outcome of a row as the boards draw it: a badge ("Passed", "At Strategy", "Dropped ·
  /// Quote") in its tone, then the detail in plain text ("stop verified", "watching for its setup",
  /// "Quote too old · 7.2s (needs <= 5.0s)").
  public static func outcome(_ row: SymbolRowV1) -> (badge: String, detail: String, tone: Tone) {
    let stage = String(localized: row.stage.title)
    switch row.state {
    case .passed:
      return (String(localized: L10n.symbolsPassed), String(localized: L10n.symbolsPassedDetail), .passed)
    case .waiting:
      let detail = row.verdict == .watch ? L10n.symbolsWatching : L10n.symbolsWaiting
      return (String(localized: L10n.symbolsAt(stage)), String(localized: detail), .waiting)
    case .dropped:
      return (String(localized: L10n.symbolsDropped(stage)), reason(row), .dropped)
    case .notReached:
      return (String(localized: L10n.symbolsNotReached(stage)), reason(row), .notReached)
    }
  }

  /// Why the row stopped where it is: the failed check as "rule measured op threshold", else the
  /// discovery cause in words with what was measured, else the bot's recorded text. A cause code
  /// this app does not know (a bot of another release) reads as "Other reason", never as the code.
  public static func reason(_ row: SymbolRowV1) -> String {
    if let check = row.check { return checkText(check) }
    switch row.stage {
    case .risk:
      // The admission's recorded "CODE: detail", as the flow's refusals read.
      return row.detail.map(FlowBoard.recordedRefusal) ?? ApiText.missing
    case .stop:
      guard let cause = row.cause else { return ApiText.missing }
      return FlowStopState(rawValue: cause).map(StageDetail.title) ?? ApiText.otherReason(cause)
    default:
      break
    }
    if row.state == .notReached {
      // Why the pass stopped, in words; the bot keeps the route's own text out of the row.
      guard let cause = row.cause else { return ApiText.missing }
      return NotReachedCause(rawValue: cause).map { String(localized: $0.title) } ?? ApiText.otherReason(cause)
    }
    let cause = row.cause.map { code in
      DiscoveryCause(rawValue: code).map { String(localized: $0.title) } ?? ApiText.otherReason(code)
    }
    let parts = [cause, row.detail].compactMap { $0 }.filter { !$0.isEmpty }
    return parts.isEmpty ? ApiText.missing : parts.joined(separator: separator)
  }

  /// "Close above VWAP 5.12 · needs >= 5.20": the rule in words, then the recorded values in
  /// words that stay true for a failed check (`CheckV1.valueText`).
  public static func checkText(_ check: CheckV1) -> String {
    let rule = ApiText.rule(check.rule)
    guard check.measured != nil || check.threshold != nil else { return rule }
    return String(localized: L10n.symbolsCheck(rule, check.valueText))
  }

  /// "Top gainers #3": a screener and the symbol's rank in it.
  public static func source(_ source: SymbolSourceV1) -> String {
    String(localized: L10n.symbolsSource(String(localized: source.kind.screenerTitle), source.rank))
  }

  /// "+18.2%": a change from the previous close.
  public static func change(_ value: DecimalString) -> String {
    String(localized: L10n.stageChange(signed(value.value, digits: changeDigits)))
  }

  // MARK: path

  /// One stage of a symbol's path today, as its detail lists it.
  public struct Step: Hashable, Sendable, Identifiable {
    public enum Mark: Hashable, Sendable {
      /// It went on past this stage.
      case passed
      /// It stands here now: waiting, dropped, not reached, or through the last stage.
      case here(Tone)
      /// It never got this far.
      case ahead
    }

    public let stage: SymbolStage
    public let mark: Mark
    /// Why it stopped here (`reason`): only on the stage it stands at, when dropped or not reached.
    public let detail: String?
    public var id: SymbolStage { stage }
  }

  /// When the row got to `step`: for the stage it stands at, the time of that state (a drop at a
  /// later pass is dated by that pass, never by when the stage was first passed); for any other
  /// stage when it was first reached. Nil where no record says when.
  public static func time(_ step: Step, row: SymbolRowV1) -> Date? {
    let reached = row.reached.first { $0.stage == step.stage }?.at?.date
    if case .here = step.mark { return row.at?.date ?? reached }
    return reached
  }

  /// Every stage in order: passed up to where the row stands, its outcome there, then ahead.
  /// A stage it went past earlier but stands before now (dropped at a later pass) reads passed.
  public static func path(_ row: SymbolRowV1) -> [Step] {
    let tone = outcome(row).tone
    return SymbolStage.allCases.map { stage in
      if stage == row.stage {
        return Step(stage: stage, mark: .here(tone), detail: tone == .dropped || tone == .notReached ? reason(row) : nil)
      }
      if stage.order < row.stage.order || stage.order <= row.furthest.order {
        return Step(stage: stage, mark: .passed, detail: nil)
      }
      return Step(stage: stage, mark: .ahead, detail: nil)
    }
  }

  // MARK: fast movers

  /// "vol 6.4×": the bar's volume against the average of the bars before it.
  public static func volume(_ mover: FastMoverV1) -> String {
    String(localized: L10n.moverVolume(fixed(mover.volumeRatio.value, digits: ratioDigits)))
  }

  /// "+2.1 ATR": the bar's move in ATRs of the bars before it.
  public static func move(_ mover: FastMoverV1) -> String {
    String(localized: L10n.moverMove(signed(mover.moveAtr.value, digits: ratioDigits)))
  }

  /// "$vol 4.1×": the bar's dollar volume against the average of the bars before it.
  public static func dollars(_ mover: FastMoverV1) -> String {
    String(localized: L10n.moverDollars(fixed(mover.dollarVolumeRatio.value, digits: ratioDigits)))
  }

  /// The one signal a row names (mockup Main, Fast movers): the fired signal furthest past its
  /// threshold, as its value over its rule; the first fired one without rules; the volume when
  /// the bot names none. The rule itself is behind the card's info button.
  public static func mainSignal(_ mover: FastMoverV1, rules: FastMoverRulesV1?) -> FastMoverSignal {
    let fired = FastMoverSignal.allCases.filter { mover.fired($0) }
    guard let rules else { return fired.first ?? .volume }
    func share(_ signal: FastMoverSignal) -> Decimal {
      let (value, rule): (Decimal, Decimal) = switch signal {
      case .volume: (mover.volumeRatio.value, rules.minVolumeRatio.value)
      case .move: (abs(mover.moveAtr.value), rules.minMoveAtr.value)
      case .dollars: (mover.dollarVolumeRatio.value, rules.minDollarVolumeRatio.value)
      }
      return rule > 0 ? value / rule : value
    }
    return (fired.isEmpty ? FastMoverSignal.allCases : fired).max { share($0) < share($1) } ?? .volume
  }

  /// The main signal's figure in words ("vol 6.4×", "+2.1 ATR", "$vol 7.2×").
  public static func mainReason(_ mover: FastMoverV1, rules: FastMoverRulesV1?) -> String {
    switch mainSignal(mover, rules: rules) {
    case .volume: volume(mover)
    case .move: move(mover)
    case .dollars: dollars(mover)
    }
  }

  /// "bar ≥ $250K, then any of: vol ≥ 5× · |move| ≥ 2 ATR · $ vol ≥ 5× · vs last 10 bars": the thresholds.
  public static func rules(_ rules: FastMoverRulesV1) -> String {
    let floor = rules.minBarDollarVolumeUsd.value.formatted(
      .currency(code: dollarCode).notation(.compactName).precision(.fractionLength(0...ratioDigits)))
    return String(localized: L10n.moverRules(rules.minVolumeRatio.text, rules.minMoveAtr.text,
      rules.minDollarVolumeRatio.text, floor, rules.lookbackBars))
  }

  /// Decimals of a change, as the flow chips write it ("+6.4%").
  public static let changeDigits = 1
  /// Decimals of a ratio or a move ("6.4×", "+2.1 ATR").
  public static let ratioDigits = 1
  /// Currency of the bot's dollar volumes (protocol constant: the API's amounts are USD).
  static let dollarCode = "USD"
  /// Between the parts of a reason.
  static let separator = " · "
  /// Shown before a positive change or move.
  static let plus = "+"

  static func fixed(_ value: Decimal, digits: Int) -> String {
    value.formatted(.number.precision(.fractionLength(digits)))
  }

  static func signed(_ value: Decimal, digits: Int) -> String {
    (value > 0 ? plus : "") + fixed(value, digits: digits)
  }
}

extension ScreenerSource {
  /// The screener's name on a symbol's source chip.
  public var screenerTitle: LocalizedStringResource {
    switch self {
    case .gainers: L10n.stageGainers
    case .losers: L10n.stageLosers
    case .topActives: L10n.stageActives
    }
  }
}

/// The signals named in `FastMoverV1.fired` (protocol constants of the API).
public enum FastMoverSignal: String, Sendable, CaseIterable {
  case volume = "volume_ratio"
  case move = "move_atr"
  case dollars = "dollar_volume_ratio"
}

extension FastMoverV1 {
  /// Whether `signal` reached its threshold on the mover's bar.
  public func fired(_ signal: FastMoverSignal) -> Bool { fired.contains(signal.rawValue) }
}
