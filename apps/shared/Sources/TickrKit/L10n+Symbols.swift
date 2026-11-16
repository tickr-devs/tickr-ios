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
  /// A fast mover's dollar volume in its one-minute bar.
  static func moverDollars(_ amount: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.mover.dollars", defaultValue: "\(amount)/min", bundle: bundle)
  }
  /// The fast mover thresholds of the active strategy.
  static func moverRules(
    _ volume: String, _ move: String, _ dollars: String, _ floor: String, _ bars: Int
  ) -> LocalizedStringResource {
    LocalizedStringResource("kit.mover.rules",
      defaultValue: "vol ≥ \(volume)× · move ≥ \(move) ATR · $ vol ≥ \(dollars)× · bar ≥ \(floor) · vs last \(bars) bars",
      bundle: bundle)
  }
}
