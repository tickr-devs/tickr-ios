import Foundation

/// Texts of the Symbols screen and the fast movers (SymbolsBoard).
extension L10n {
  /// Funnel stage: the screeners' lists.
  static var symbolStageScreeners: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.screeners", defaultValue: "Found", bundle: bundle)
  }
  /// Funnel stage: the universe filter (common stocks, exchange, type).
  static var symbolStageUniverse: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.universe", defaultValue: "Stocks", bundle: bundle)
  }
  /// Funnel stage: a fresh quote and a tight spread.
  static var symbolStageQuote: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.quote", defaultValue: "Price ok", bundle: bundle)
  }
  /// Funnel stage: minute bars and enough dollar volume.
  static var symbolStageBars: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.bars", defaultValue: "Volume ok", bundle: bundle)
  }
  /// Funnel stage: the decision to enter or not.
  static var symbolStageStrategy: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.strategy", defaultValue: "Decision", bundle: bundle)
  }
  /// Funnel stage: the platform's risk admission.
  static var symbolStageRisk: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.risk", defaultValue: "Risk ok", bundle: bundle)
  }
  /// Funnel stage: the entry order.
  static var symbolStageOrder: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.order", defaultValue: "Bought", bundle: bundle)
  }
  /// Funnel stage: the broker-side stop.
  static var symbolStageStop: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.stop", defaultValue: "Stop set", bundle: bundle)
  }
  /// Symbols with a sudden jump against the previous bars.
  static var symbolsFastMovers: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fastMovers", defaultValue: "Fast movers", bundle: bundle)
  }
  /// Symbols filter: every symbol that reached the stage.
  static var symbolsFilterAll: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.filter.all", defaultValue: "All", bundle: bundle)
  }
  /// Symbols filter: the ones that went on past the stage.
  static var symbolsFilterPassed: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.filter.passed", defaultValue: "Passed", bundle: bundle)
  }
  /// Symbols filter: the ones the stage dropped.
  static var symbolsFilterDropped: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.filter.dropped", defaultValue: "Dropped here", bundle: bundle)
  }
  /// Sort: furthest stage first.
  static var symbolsSortFurthest: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.sort.furthest", defaultValue: "Furthest stage", bundle: bundle)
  }
  /// Sort: by symbol.
  static var symbolsSortSymbol: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.sort.symbol", defaultValue: "Symbol", bundle: bundle)
  }
  /// Sort: best screener rank first.
  static var symbolsSortRank: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.sort.rank", defaultValue: "Screener rank", bundle: bundle)
  }
  /// Sort: biggest change first.
  static var symbolsSortChange: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.sort.change", defaultValue: "Change %", bundle: bundle)
  }
  /// Outcome badge: through every stage.
  static var symbolsPassed: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.passed", defaultValue: "Passed", bundle: bundle)
  }
  /// Outcome detail after the Passed badge: its broker stop verified.
  static var symbolsPassedDetail: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.passedDetail", defaultValue: "Stop verified at broker", bundle: bundle)
  }
  /// Outcome badge: still at a stage, nothing failed; argument: stage.
  static func symbolsAt(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.at", defaultValue: "At \(stage)", bundle: bundle)
  }
  /// Outcome detail after the At badge: the strategy watches it.
  static var symbolsWatching: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.watching", defaultValue: "watching for its setup", bundle: bundle)
  }
  /// Outcome detail after the At badge: the next step has not happened yet.
  static var symbolsWaiting: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.waiting", defaultValue: "waiting", bundle: bundle)
  }
  /// Outcome badge: dropped at a stage (the reason follows); argument: stage.
  static func symbolsDropped(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.dropped", defaultValue: "Dropped · \(stage)", bundle: bundle)
  }
  /// Outcome badge: the discovery pass stopped before deciding it (the reason follows); argument:
  /// stage.
  static func symbolsNotReached(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.notReached", defaultValue: "Not reached · \(stage)", bundle: bundle)
  }
  /// A failed check: the rule, then its values in words (`CheckV1.valueText`).
  static func symbolsCheck(_ rule: String, _ values: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.check", defaultValue: "\(rule) \(values)", bundle: bundle)
  }
  /// A screener and the symbol's rank in it.
  static func symbolsSource(_ screener: String, _ rank: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.source", defaultValue: "\(screener) #\(rank)", bundle: bundle)
  }
  /// A fast mover's bar volume against the average.
  static func moverVolume(_ ratio: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.mover.volume", defaultValue: "vol \(ratio)×", bundle: bundle)
  }
  /// A fast mover's move in ATRs.
  static func moverMove(_ atr: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.mover.move", defaultValue: "\(atr) ATR", bundle: bundle)
  }
  /// A fast mover's dollar volume against the average of the bars before it.
  static func moverDollars(_ ratio: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.mover.dollars", defaultValue: "$vol \(ratio)×", bundle: bundle)
  }
  /// The fast mover thresholds of the active strategy: a bar above the floor that meets any one signal.
  static func moverRules(
    _ vol: String, _ atr: String, _ dvol: String, _ bar: String, _ n: Int
  ) -> LocalizedStringResource {
    LocalizedStringResource("kit.mover.rules",
      defaultValue: "bar ≥ \(bar), then any of: vol ≥ \(vol)× · |move| ≥ \(atr) ATR · $ vol ≥ \(dvol)× · vs last \(n) bars",
      bundle: bundle)
  }
  /// Column title of the Symbols table.
  static var symbolsColumnSymbol: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.symbol", defaultValue: "Symbol", bundle: bundle)
  }
  /// Column title: the last price.
  static var symbolsColumnLast: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.last", defaultValue: "Last", bundle: bundle)
  }
  /// Column title: the change from the previous close.
  static var symbolsColumnChange: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.change", defaultValue: "Chg %", bundle: bundle)
  }
  /// Column title: the fast bar's volume against the bars before.
  static var symbolsColumnVolume: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.volume", defaultValue: "Volume", bundle: bundle)
  }
  /// Column title: the fast bar's move in ATR.
  static var symbolsColumnAtr: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.atr", defaultValue: "Move", bundle: bundle)
  }
  /// Column title: the fast bar's dollar volume against the bars before.
  static var symbolsColumnDollars: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.dollars", defaultValue: "$ traded", bundle: bundle)
  }
  /// Column title: the best-ranked screener.
  static var symbolsColumnScreener: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.screener", defaultValue: "Screener", bundle: bundle)
  }
  /// Column title: the furthest stage reached.
  static var symbolsColumnStage: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.stage", defaultValue: "Stage", bundle: bundle)
  }
  /// Column title: the outcome and why.
  static var symbolsColumnOutcome: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.outcome", defaultValue: "Result", bundle: bundle)
  }
  /// Column title: when a screener first listed it.
  static var symbolsColumnSeen: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.seen", defaultValue: "Seen", bundle: bundle)
  }
  /// Column title on the Fast movers tab: the fast bar's time.
  static var symbolsColumnFlagged: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.flagged", defaultValue: "Flagged", bundle: bundle)
  }
  /// Outcome badge: through the last stage.
  static var symbolsOutcomePassed: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.outcome.passed", defaultValue: "Entered", bundle: bundle)
  }
  /// Outcome badge: nothing failed, the next stage has not happened yet.
  static var symbolsOutcomeWaiting: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.outcome.waiting", defaultValue: "Waiting", bundle: bundle)
  }
  /// Outcome badge: refused at its stage.
  static var symbolsOutcomeDropped: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.outcome.dropped", defaultValue: "Dropped", bundle: bundle)
  }
  /// Outcome badge: the latest pass stopped before deciding it.
  static var symbolsOutcomeNotReached: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.outcome.notReached", defaultValue: "Not reached", bundle: bundle)
  }
  /// A rise from the previous close, in percent.
  static func symbolsChangeUp(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.changeUp", defaultValue: "▲ \(value)%", bundle: bundle)
  }
  /// A fall from the previous close, in percent.
  static func symbolsChangeDown(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.changeDown", defaultValue: "▼ \(value)%", bundle: bundle)
  }
  /// A multiple of the average ("6.4×").
  static func symbolsRatio(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.ratio", defaultValue: "\(value)×", bundle: bundle)
  }
  /// A screener's full name.
  static var symbolsScreenerGainers: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.screener.gainers", defaultValue: "Top gainers", bundle: bundle)
  }
  /// A screener's full name.
  static var symbolsScreenerLosers: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.screener.losers", defaultValue: "Top losers", bundle: bundle)
  }
  /// A screener's full name.
  static var symbolsScreenerActives: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.screener.actives", defaultValue: "Most active", bundle: bundle)
  }
  /// Badge of a symbol with an open position ("Open").
  static var symbolsPosition: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.position", defaultValue: "Open", bundle: bundle)
  }
  /// When a screener first listed the symbol.
  static func symbolsSeen(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.seen", defaultValue: "first seen \(time)", bundle: bundle)
  }
  /// Beside the price: the change is today's.
  static var symbolsToday: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.today", defaultValue: "today", bundle: bundle)
  }
  /// Where a waiting or dropped symbol stands.
  static func symbolsAtStage(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.atStage", defaultValue: "at \(stage)", bundle: bundle)
  }
  /// A stage of the path the symbol never got to.
  static var symbolsStepNotReached: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.step.notReached", defaultValue: "not reached", bundle: bundle)
  }
  /// How to sort and move through the table.
  static var symbolsSortHint: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.sortHint", defaultValue: "click a column to sort · ↑↓ to move", bundle: bundle)
  }
  /// A filter of the table with how many rows it holds.
  static func symbolsFilterCount(_ title: String, _ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.filterCount", defaultValue: "\(title) \(count)", bundle: bundle)
  }
  /// Outcome badge: the decision said not to enter.
  static var symbolsOutcomeSkipped: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.outcome.skipped", defaultValue: "Skipped", bundle: bundle)
  }
  /// Detail headline: chosen to enter, then stopped by risk, the order or the stop.
  static var symbolsNotEntered: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.notEntered", defaultValue: "Not entered", bundle: bundle)
  }
  /// One-line caption of a stage tab: the screeners' lists.
  static var symbolsCaptionScreeners: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.screeners", defaultValue: "From the screeners", bundle: bundle)
  }
  /// One-line caption of a stage tab: the universe filter.
  static var symbolsCaptionUniverse: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.universe", defaultValue: "Common stocks only", bundle: bundle)
  }
  /// One-line caption of a stage tab: a fresh quote and a tight spread.
  static var symbolsCaptionQuote: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.quote", defaultValue: "Fresh price, tight spread", bundle: bundle)
  }
  /// One-line caption of a stage tab: enough dollar volume.
  static var symbolsCaptionBars: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.bars", defaultValue: "Enough trading", bundle: bundle)
  }
  /// One-line caption of the decision tab: how many of the decided symbols were chosen to enter;
  /// arguments: chosen, decided.
  static func symbolsCaptionDecision(_ chosen: Int, _ decided: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.strategy", defaultValue: "\(chosen) of \(decided) chosen to enter",
      bundle: bundle)
  }
  /// One-line caption of a stage tab: the platform's risk admission.
  static var symbolsCaptionRisk: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.risk", defaultValue: "Within risk limits", bundle: bundle)
  }
  /// One-line caption of a stage tab: the entry order.
  static var symbolsCaptionOrder: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.order", defaultValue: "Order filled", bundle: bundle)
  }
  /// One-line caption of a stage tab: the broker-side stop.
  static var symbolsCaptionStop: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.stop", defaultValue: "Stop at broker", bundle: bundle)
  }
  /// One-line caption of the Fast movers tab.
  static var symbolsCaptionFast: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.caption.fast", defaultValue: "Sudden jump since the last bar", bundle: bundle)
  }
  /// The fast mover rule in words, behind the "i" button; arguments: the bar's least dollar volume,
  /// the volume ratio, the move in ATRs, the dollar volume ratio, the bars compared with.
  static func symbolsFastRule(
    _ bar: String, _ vol: String, _ atr: String, _ dvol: String, _ n: Int
  ) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fastRule",
      // swiftlint:disable:next line_length
      defaultValue: "Flagged when a one-minute bar trades at least \(bar) and its volume is \(vol)× the last \(n) bars, or it moves \(atr)× its usual range (ATR), or its dollars traded are \(dvol)×. Open positions and waiting symbols stay on top.",
      bundle: bundle)
  }
  /// Label of the button that shows the fast mover rule.
  static var symbolsFastRuleLabel: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fastRuleLabel", defaultValue: "How a fast mover is flagged", bundle: bundle)
  }
  /// A fast mover's signal that fired: the bar's volume against the bars before.
  static func symbolsFiredVolume(_ ratio: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fired.volume", defaultValue: "Volume \(ratio)", bundle: bundle)
  }
  /// A fast mover's signal that fired: the bar's move in ATRs.
  static func symbolsFiredMove(_ atr: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fired.move", defaultValue: "Move \(atr)", bundle: bundle)
  }
  /// A fast mover's signal that fired: the bar's dollars traded against the bars before.
  static func symbolsFiredDollars(_ ratio: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fired.dollars", defaultValue: "$ traded \(ratio)", bundle: bundle)
  }
  /// The detail's fast mover line: when the bar started, then its fired signals.
  static func symbolsFastNote(_ time: String, _ signals: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fastNote", defaultValue: "Fast mover at \(time) · \(signals)", bundle: bundle)
  }
  /// The detail's screeners and when the first listed the symbol; arguments: the screeners with
  /// their ranks, the time.
  static func symbolsFoundBy(_ screeners: String, _ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.foundBy", defaultValue: "Found by \(screeners) · first seen \(time)",
      bundle: bundle)
  }
  /// The detail's steps disclosure: stages passed of all; arguments: passed, all.
  static func symbolsStepsPassed(_ passed: Int, _ total: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stepsPassed", defaultValue: "\(passed) of \(total) passed", bundle: bundle)
  }
  /// The detail's steps disclosure title.
  static var symbolsStepsToday: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stepsToday", defaultValue: "Steps today", bundle: bundle)
  }
}
