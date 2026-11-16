import Foundation

/// Texts of the Symbols screen and the fast movers (SymbolsBoard).
extension L10n {
  /// Funnel stage: the screeners' lists.
  static var symbolStageScreeners: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.screeners", defaultValue: "Screeners", bundle: bundle)
  }
  /// Funnel stage: the universe filter (common stocks, exchange, type).
  static var symbolStageUniverse: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.universe", defaultValue: "Universe", bundle: bundle)
  }
  /// Funnel stage: a fresh quote and the strategy's spread rule.
  static var symbolStageQuote: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.quote", defaultValue: "Quote", bundle: bundle)
  }
  /// Funnel stage: minute bars and the strategy's dollar volume rule.
  static var symbolStageBars: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.bars", defaultValue: "Bars", bundle: bundle)
  }
  /// Funnel stage: the strategy's decision.
  static var symbolStageStrategy: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.strategy", defaultValue: "Strategy", bundle: bundle)
  }
  /// Funnel stage: the platform's risk admission.
  static var symbolStageRisk: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.risk", defaultValue: "Risk", bundle: bundle)
  }
  /// Funnel stage: the entry order.
  static var symbolStageOrder: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.order", defaultValue: "Order", bundle: bundle)
  }
  /// Funnel stage: the broker-side stop.
  static var symbolStageStop: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stage.stop", defaultValue: "Broker stop", bundle: bundle)
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
  /// Outcome: through every stage, its broker stop verified.
  static var symbolsPassed: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.passed", defaultValue: "Passed · stop verified", bundle: bundle)
  }
  /// Outcome: the strategy watches it; argument: stage.
  static func symbolsWatching(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.watching", defaultValue: "\(stage): watching for its setup", bundle: bundle)
  }
  /// Outcome: nothing failed, the next step has not happened yet; argument: stage.
  static func symbolsWaiting(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.waiting", defaultValue: "\(stage): waiting", bundle: bundle)
  }
  /// Outcome: dropped at a stage; arguments: stage, why.
  static func symbolsDropped(_ stage: String, _ reason: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.dropped", defaultValue: "\(stage): \(reason)", bundle: bundle)
  }
  /// Outcome: the discovery pass stopped before deciding it; arguments: stage, why.
  static func symbolsNotReached(_ stage: String, _ reason: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.notReached", defaultValue: "\(stage) not reached: \(reason)", bundle: bundle)
  }
  /// A failed check: rule, measured, operator, threshold.
  static func symbolsCheck(_ rule: String, _ measured: String, _ op: String, _ threshold: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.check", defaultValue: "\(rule) \(measured) \(op) \(threshold)", bundle: bundle)
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
    LocalizedStringResource("kit.symbols.column.volume", defaultValue: "Vol ×", bundle: bundle)
  }
  /// Column title: the fast bar's move in ATR.
  static var symbolsColumnAtr: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.atr", defaultValue: "ATR", bundle: bundle)
  }
  /// Column title: the fast bar's dollar volume against the bars before.
  static var symbolsColumnDollars: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.column.dollars", defaultValue: "$vol ×", bundle: bundle)
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
    LocalizedStringResource("kit.symbols.column.outcome", defaultValue: "Outcome · reason", bundle: bundle)
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
    LocalizedStringResource("kit.symbols.outcome.passed", defaultValue: "Passed", bundle: bundle)
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
  /// How many other screeners listed the symbol.
  static func symbolsMore(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.more", defaultValue: "+\(count)", bundle: bundle)
  }
  /// A fast mover figure that reached its threshold.
  static func symbolsMoverMet(_ threshold: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.mover.met", defaultValue: "met ≥ \(threshold)", bundle: bundle)
  }
  /// A fast mover figure below its threshold.
  static func symbolsMoverUnmet(_ threshold: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.mover.unmet", defaultValue: "< \(threshold)", bundle: bundle)
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
  /// Badge of a symbol with an open position.
  static var symbolsPosition: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.position", defaultValue: "Position", bundle: bundle)
  }
  /// When a screener first listed the symbol.
  static func symbolsSeen(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.seen", defaultValue: "seen \(time)", bundle: bundle)
  }
  /// Beside the price: the change is today's.
  static var symbolsToday: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.today", defaultValue: "today", bundle: bundle)
  }
  /// Where a waiting or dropped symbol stands.
  static func symbolsAtStage(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.atStage", defaultValue: "at \(stage)", bundle: bundle)
  }
  /// How far a symbol that passed got.
  static func symbolsReachedStage(_ stage: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.reachedStage", defaultValue: "reached \(stage)", bundle: bundle)
  }
  /// Detail section: the symbol's fast bar.
  static var symbolsFastMover: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.fastMover", defaultValue: "Fast mover", bundle: bundle)
  }
  /// When the fast bar started.
  static func symbolsFlagged(_ time: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.flagged", defaultValue: "flagged \(time)", bundle: bundle)
  }
  /// A symbol without a fast bar today.
  static var symbolsNotFlagged: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.notFlagged", defaultValue: "not flagged today", bundle: bundle)
  }
  /// Fast mover stat: volume against the bars before.
  static var symbolsStatVolume: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stat.volume", defaultValue: "Vol ×", bundle: bundle)
  }
  /// Fast mover stat: the bar's move in ATR.
  static var symbolsStatMove: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stat.move", defaultValue: "Move ATR", bundle: bundle)
  }
  /// Fast mover stat: dollar volume against the bars before.
  static var symbolsStatDollars: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.stat.dollars", defaultValue: "$ vol ×", bundle: bundle)
  }
  /// Detail section: the screeners that listed the symbol.
  static var symbolsScreeners: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.screeners", defaultValue: "Screeners", bundle: bundle)
  }
  /// A rank in a screener's list.
  static func symbolsRank(_ rank: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.rank", defaultValue: "#\(rank)", bundle: bundle)
  }
  /// Detail section: the strategy's latest decision.
  static var symbolsLastDecision: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.lastDecision", defaultValue: "Last strategy decision", bundle: bundle)
  }
  /// When the strategy decided, and which strategy.
  static func symbolsDecided(_ time: String, _ strategy: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.symbols.decided", defaultValue: "\(time) · \(strategy)", bundle: bundle)
  }
  /// A symbol the strategy did not decide on.
  static var symbolsNoDecision: LocalizedStringResource {
    LocalizedStringResource("kit.symbols.noDecision", defaultValue: "No strategy decision today.", bundle: bundle)
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
}
