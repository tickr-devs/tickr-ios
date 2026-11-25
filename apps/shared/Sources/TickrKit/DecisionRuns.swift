import Foundation

/// Repeats of one decision in a row: the same strategy reaching the same outcome bar
/// after bar, shown as one line with a count. `decisions` are newest first.
public struct DecisionRun: Hashable, Sendable {
  public let decisions: [DecisionV1]

  /// The newest decision of the run.
  public var latest: DecisionV1 { decisions[0] }
  /// The oldest decision of the run.
  public var earliest: DecisionV1 { decisions[decisions.count - 1] }
  public var count: Int { decisions.count }

  /// Decisions in the order given, merged where one follows another with the same outcome: the
  /// same strategy, verdict, what-if levels present or not (a taken ENTER never merges with a
  /// refused one) and the same checks passed and failed.
  public static func merge(_ decisions: [DecisionV1]) -> [DecisionRun] {
    var runs: [[DecisionV1]] = []
    for decision in decisions {
      if let last = runs.last?.last, sameOutcome(last, decision) {
        runs[runs.count - 1].append(decision)
      } else {
        runs.append([decision])
      }
    }
    return runs.map(DecisionRun.init(decisions:))
  }

  static func sameOutcome(_ a: DecisionV1, _ b: DecisionV1) -> Bool {
    a.strategy == b.strategy && a.action == b.action
      && (a.entryPrice == nil) == (b.entryPrice == nil) && (a.stopPrice == nil) == (b.stopPrice == nil)
      && a.checks.map(\.rule) == b.checks.map(\.rule) && a.checks.map(\.passed) == b.checks.map(\.passed)
  }
}

/// What the chart lists under "why the bot acted": the trading strategy's decisions, newest first,
/// with repeats merged into runs. Only entries and exits unless `everything` is asked for. A
/// shadow strategy's decisions (`observer`, from a bot configured with one) are left out.
public struct DecisionList: Hashable, Sendable {
  /// The trading strategy's runs.
  public let strategy: [DecisionRun]
  /// The trading strategy's decisions of every verdict, before any filter.
  public let total: Int
  /// Entries and exits, before merging.
  public let key: Int

  /// Whether a decision changes or would change a position.
  public static func isKey(_ decision: DecisionV1) -> Bool {
    decision.action == .enter || decision.action == .exit
  }

  /// `decisions` as the bot serves them (oldest first). Runs are merged over every decision of the
  /// strategy before the filter, so two entries an hour apart with holding between them stay two.
  public init(_ decisions: [DecisionV1], everything: Bool) {
    let trading = decisions.filter { !$0.observer }
    let keep: (DecisionRun) -> Bool = { everything || Self.isKey($0.latest) }
    strategy = DecisionRun.merge(trading.reversed()).filter(keep)
    total = trading.count
    key = trading.filter(Self.isKey).count
  }

  /// Nothing to list under the current filter.
  public var isEmpty: Bool { strategy.isEmpty }
}

/// The order of the chart's symbol chips: open positions first, then symbols traded that day
/// (most recent first), then every other symbol with bars, each once and only if it has bars.
public enum ChartSymbols {
  public static func ordered(_ symbols: [String], open: [String], traded: [String]) -> [String] {
    var result: [String] = []
    for symbol in open + traded.reversed() + symbols where symbols.contains(symbol) && !result.contains(symbol) {
      result.append(symbol)
    }
    return result
  }
}
