import Foundation

/// Texts of the live flow's stage details (StageDetail).
extension L10n {
  /// A stage's detail card with nothing to show.
  static var stageNothing: LocalizedStringResource {
    LocalizedStringResource("kit.stage.nothing", defaultValue: "Nothing reported for this stage yet", bundle: bundle)
  }
  /// Screener: biggest gainers.
  static var stageGainers: LocalizedStringResource {
    LocalizedStringResource("kit.stage.gainers", defaultValue: "Gainers", bundle: bundle)
  }
  /// Screener: biggest losers.
  static var stageLosers: LocalizedStringResource {
    LocalizedStringResource("kit.stage.losers", defaultValue: "Losers", bundle: bundle)
  }
  /// Screener: most active.
  static var stageActives: LocalizedStringResource {
    LocalizedStringResource("kit.stage.actives", defaultValue: "Most active", bundle: bundle)
  }
  /// Symbols the screeners listed on the day.
  static var stageListed: LocalizedStringResource {
    LocalizedStringResource("kit.stage.listed", defaultValue: "Listed in all", bundle: bundle)
  }
  /// Group: the strongest gainers.
  static var stageTopGainers: LocalizedStringResource {
    LocalizedStringResource("kit.stage.topGainers", defaultValue: "Strongest gainers", bundle: bundle)
  }
  /// Group: the strongest losers.
  static var stageTopLosers: LocalizedStringResource {
    LocalizedStringResource("kit.stage.topLosers", defaultValue: "Strongest losers", bundle: bundle)
  }
  /// A change from the previous close; argument: signed percent.
  static func stageChange(_ value: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.change", defaultValue: "\(value)%", bundle: bundle)
  }
  /// Symbols the universe filter admitted.
  static var stageAdmitted: LocalizedStringResource {
    LocalizedStringResource("kit.stage.admitted", defaultValue: "Admitted", bundle: bundle)
  }
  /// "3 of 4".
  static func stageCountOf(_ count: Int, _ total: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.countOf", defaultValue: "\(count) of \(total)", bundle: bundle)
  }
  /// The strategy the bot runs.
  static var stageActiveStrategy: LocalizedStringResource {
    LocalizedStringResource("kit.stage.activeStrategy", defaultValue: "Active strategy", bundle: bundle)
  }
  /// A strategy and its version.
  static func stageStrategy(_ name: String, _ version: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.strategy", defaultValue: "\(name) v\(version)", bundle: bundle)
  }
  /// Symbols the strategy decided on.
  static var stageDecided: LocalizedStringResource {
    LocalizedStringResource("kit.stage.decided", defaultValue: "Decided on today", bundle: bundle)
  }
  /// Group: watched symbols nearest an entry.
  static var stageClosest: LocalizedStringResource {
    LocalizedStringResource("kit.stage.closest", defaultValue: "Closest to entering", bundle: bundle)
  }
  /// How close the deciding check is to passing.
  static func stageCloseness(_ percent: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.closeness", defaultValue: "\(percent)% there", bundle: bundle)
  }
  /// Signals risk passed.
  static var stagePassed: LocalizedStringResource {
    LocalizedStringResource("kit.stage.passed", defaultValue: "Passed", bundle: bundle)
  }
  /// Signals risk refused.
  static var stageRefused: LocalizedStringResource {
    LocalizedStringResource("kit.stage.refused", defaultValue: "Refused", bundle: bundle)
  }
  /// Signals risk did not evaluate.
  static var stageNotEvaluated: LocalizedStringResource {
    LocalizedStringResource("kit.stage.notEvaluated", defaultValue: "Not evaluated", bundle: bundle)
  }
  /// Whether new entries are allowed now.
  static var stageEntries: LocalizedStringResource {
    LocalizedStringResource("kit.stage.entries", defaultValue: "Entries now", bundle: bundle)
  }
  /// New entries are allowed.
  static var stageEntriesAllowed: LocalizedStringResource {
    LocalizedStringResource("kit.stage.entriesAllowed", defaultValue: "Allowed", bundle: bundle)
  }
  /// Setting: planned loss.
  static var stagePlannedLoss: LocalizedStringResource {
    LocalizedStringResource("kit.stage.plannedLoss", defaultValue: "Planned loss per trade", bundle: bundle)
  }
  /// Setting: daily loss limit.
  static var stageMaxDailyLoss: LocalizedStringResource {
    LocalizedStringResource("kit.stage.maxDailyLoss", defaultValue: "Max daily loss", bundle: bundle)
  }
  /// Setting: position slots.
  static var stageMaxPositions: LocalizedStringResource {
    LocalizedStringResource("kit.stage.maxPositions", defaultValue: "Max open positions", bundle: bundle)
  }
  /// Room left under the daily loss limit.
  static var stageRoomLeft: LocalizedStringResource {
    LocalizedStringResource("kit.stage.roomLeft", defaultValue: "Daily room left", bundle: bundle)
  }
  /// Open positions of the slots.
  static var stagePositionsUsed: LocalizedStringResource {
    LocalizedStringResource("kit.stage.positionsUsed", defaultValue: "Positions in use", bundle: bundle)
  }
  /// The latest entry size.
  static var stageLatestSize: LocalizedStringResource {
    LocalizedStringResource("kit.stage.latestSize", defaultValue: "Latest size", bundle: bundle)
  }
  /// Symbol and quantity.
  static func stageSize(_ symbol: String, _ quantity: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.size", defaultValue: "\(symbol) × \(quantity)", bundle: bundle)
  }
  /// An amount in dollars.
  static func stageUSD(_ amount: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.usd", defaultValue: "\(amount) USD", bundle: bundle)
  }
  /// Group: signals risk refused.
  static var stageRefusedSignals: LocalizedStringResource {
    LocalizedStringResource("kit.stage.refusedSignals", defaultValue: "Refused signals", bundle: bundle)
  }
  /// Orders filled.
  static var stageFilled: LocalizedStringResource {
    LocalizedStringResource("kit.stage.filled", defaultValue: "Filled", bundle: bundle)
  }
  /// Count of closed trades.
  static var stageClosed: LocalizedStringResource {
    LocalizedStringResource("kit.stage.closed", defaultValue: "Closed trades", bundle: bundle)
  }
  /// Count of open positions.
  static var stageOpen: LocalizedStringResource {
    LocalizedStringResource("kit.stage.open", defaultValue: "Open positions", bundle: bundle)
  }
  /// Group: trades closed today.
  static var stageClosedTrades: LocalizedStringResource {
    LocalizedStringResource("kit.stage.closedTrades", defaultValue: "Closed today", bundle: bundle)
  }
  /// Group: positions open now.
  static var stageOpenPositions: LocalizedStringResource {
    LocalizedStringResource("kit.stage.openPositions", defaultValue: "Open now", bundle: bundle)
  }
  /// Quantity, entry, exit and result.
  static func stageTrade(_ quantity: String, _ entry: String, _ exit: String, _ result: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.trade", defaultValue: "\(quantity) @ \(entry) → \(exit) · \(result)", bundle: bundle)
  }
  /// Quantity and entry.
  static func stagePosition(_ quantity: String, _ entry: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.position", defaultValue: "\(quantity) @ \(entry)", bundle: bundle)
  }
  /// Stops the broker confirmed.
  static var stageVerified: LocalizedStringResource {
    LocalizedStringResource("kit.stage.verified", defaultValue: "Verified", bundle: bundle)
  }
  /// Trades with a stop record.
  static var stageTrades: LocalizedStringResource {
    LocalizedStringResource("kit.stage.trades", defaultValue: "Trades today", bundle: bundle)
  }
  /// Group: each trade's stop.
  static var stageTradeStops: LocalizedStringResource {
    LocalizedStringResource("kit.stage.tradeStops", defaultValue: "Stops of today's trades", bundle: bundle)
  }
  /// A stop the broker never confirmed.
  static var stageNeverVerified: LocalizedStringResource {
    LocalizedStringResource("kit.stage.neverVerified", defaultValue: "never confirmed", bundle: bundle)
  }
  /// Seconds to the stop's confirmation.
  static func stageConfirmedAfter(_ seconds: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.stage.confirmedAfter", defaultValue: "confirmed in \(seconds) s", bundle: bundle)
  }
  /// Whether the bot's records agree with the broker.
  static var stageRecords: LocalizedStringResource {
    LocalizedStringResource("kit.stage.records", defaultValue: "Records", bundle: bundle)
  }
  /// Records agree.
  static var stageMatch: LocalizedStringResource {
    LocalizedStringResource("kit.stage.match", defaultValue: "Match the broker", bundle: bundle)
  }
  /// Records disagree.
  static var stageMismatch: LocalizedStringResource {
    LocalizedStringResource("kit.stage.mismatch", defaultValue: "Differ from the broker", bundle: bundle)
  }
  /// Time of the reconciliation's broker read.
  static var stageReadAt: LocalizedStringResource {
    LocalizedStringResource("kit.stage.readAt", defaultValue: "Broker read at", bundle: bundle)
  }
  /// What differs.
  static var stageMismatchDetail: LocalizedStringResource {
    LocalizedStringResource("kit.stage.mismatchDetail", defaultValue: "Difference", bundle: bundle)
  }
  /// Count of fences.
  static var stageFences: LocalizedStringResource {
    LocalizedStringResource("kit.stage.fences", defaultValue: "Fences", bundle: bundle)
  }
  /// Group: the fences.
  static var stageFenceList: LocalizedStringResource {
    LocalizedStringResource("kit.stage.fenceList", defaultValue: "Fences", bundle: bundle)
  }
}
