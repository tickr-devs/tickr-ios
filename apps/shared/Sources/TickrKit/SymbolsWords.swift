import Foundation

// The Symbols screen in plain words (mockups MacSymbols and IOSSymbols, 2026-11-25): a caption per
// tab, a short reason per line with the measured values kept for the detail's steps, the
// detail's one-word headline, the screeners that found a symbol, and the fast mover's signals
// and rule as sentences. Pure, so both apps word it alike.

extension SymbolsBoard {
  /// The one-line caption of a tab, under the screen's title: what its stage checks, on the
  /// decision tab how many of the decided symbols were chosen to enter.
  public static func caption(_ tab: SymbolsTab, symbols: SymbolsV1?) -> String {
    switch tab {
    case .fastMovers:
      return String(localized: L10n.symbolsCaptionFast)
    case .stage(.strategy):
      let decided = count(.stage(.strategy), symbols: symbols, movers: nil)
      let chosen = count(.stage(.risk), symbols: symbols, movers: nil)
      guard let decided, let chosen else { return String(localized: SymbolStage.strategy.title) }
      return String(localized: L10n.symbolsCaptionDecision(chosen, decided))
    case .stage(let stage):
      return String(localized: stage.caption)
    }
  }

  /// The short reason a list line shows ("Quote too old", "Volume ratio"): the cause or the rule in
  /// words without the measured values, which stay in the detail's steps (`reason`). Nil once
  /// the row passed.
  public static func shortWhy(_ row: SymbolRowV1) -> String? {
    switch row.state {
    case .passed: return nil
    case .waiting:
      return row.checks.first { !$0.passed }.map { ApiText.rule($0.rule) } ?? outcome(row).detail
    case .dropped, .notReached: break
    }
    if let check = row.check { return ApiText.rule(check.rule) }
    if row.stage == .risk, let detail = row.detail, RefusalCause(detail).hasCode {
      return String(localized: L10n.refusedByRisk)
    }
    if row.state == .dropped, ![.risk, .stop].contains(row.stage), let code = row.cause,
      let known = DiscoveryCause(rawValue: code) {
      return String(localized: known.title)
    }
    return reason(row)
  }

  /// The detail's headline: what happened in one word (Entered, Waiting, Skipped, Not entered,
  /// Dropped, Not reached) and one caption, where it stands and why in short.
  public static func headline(_ row: SymbolRowV1) -> (title: LocalizedStringResource, caption: String) {
    let outcome = SymbolsOutcome(row)
    if outcome == .passed { return (outcome.title, String(localized: L10n.symbolsPassedDetail)) }
    let afterDecision = row.stage.order > SymbolStage.strategy.order
    let title = outcome == .dropped && afterDecision ? L10n.symbolsNotEntered : outcome.title
    let place = String(localized: L10n.symbolsAtStage(String(localized: row.stage.title)))
    return (title, [place, shortWhy(row)].compactMap { $0 }.joined(separator: separator))
  }

  /// "Top gainers #3, Most active #7": the screeners that listed the row, best rank first; nil
  /// without one.
  public static func foundBy(_ row: SymbolRowV1) -> String? {
    guard !row.sources.isEmpty else { return nil }
    return row.sources.sorted { $0.rank < $1.rank }.map { source in
      String(localized: L10n.symbolsSource(String(localized: source.kind.fullTitle), source.rank))
    }.joined(separator: listSeparator)
  }

  /// How many stages of `path` the row went past (a row through the last stage passed all).
  public static func stepsPassed(_ row: SymbolRowV1) -> Int {
    path(row).filter { $0.mark == .passed || $0.mark == .here(.passed) }.count
  }

  /// The signals of a fast bar that reached their thresholds, in words ("Volume 6.4× · Move +2.1").
  public static func firedSignals(_ mover: FastMoverV1) -> [String] {
    FastMoverSignal.allCases.filter { mover.fired($0) }.map { signal in
      switch signal {
      case .volume: String(localized: L10n.symbolsFiredVolume(ratio(mover.volumeRatio)))
      case .move: String(localized: L10n.symbolsFiredMove(atr(mover.moveAtr)))
      case .dollars: String(localized: L10n.symbolsFiredDollars(ratio(mover.dollarVolumeRatio)))
      }
    }
  }

  /// "Fast mover at 10:47 · Volume 6.4× · Move +2.1": when the bar started and what fired.
  public static func fastNote(_ mover: FastMoverV1, time: String) -> String {
    String(localized: L10n.symbolsFastNote(time, firedSignals(mover).joined(separator: separator)))
  }

  /// The fast mover rule in one plain sentence, behind the screen's "i" button.
  public static func fastRule(_ rules: FastMoverRulesV1) -> String {
    String(localized: L10n.symbolsFastRule(barFloor(rules), rules.minVolumeRatio.text, rules.minMoveAtr.text,
      rules.minDollarVolumeRatio.text, rules.lookbackBars))
  }

  /// "$250K": the least dollar volume of a fast bar.
  static func barFloor(_ rules: FastMoverRulesV1) -> String {
    rules.minBarDollarVolumeUsd.value.formatted(
      .currency(code: dollarCode).notation(.compactName).precision(.fractionLength(0...ratioDigits)))
  }
}

extension SymbolStage {
  /// What the stage checks, in a few plain words (the decision's caption counts, see
  /// `SymbolsBoard.caption`).
  var caption: LocalizedStringResource {
    switch self {
    case .screeners: L10n.symbolsCaptionScreeners
    case .universe: L10n.symbolsCaptionUniverse
    case .quote: L10n.symbolsCaptionQuote
    case .bars: L10n.symbolsCaptionBars
    case .strategy: L10n.symbolStageStrategy
    case .risk: L10n.symbolsCaptionRisk
    case .order: L10n.symbolsCaptionOrder
    case .stop: L10n.symbolsCaptionStop
    }
  }
}
