import Foundation

/// A decision of the trading strategy marked on the candle it fell in: where it began watching a
/// symbol and where it said enter. Observers' decisions are left out; they never trade.
public struct ChartEvent: Hashable, Sendable, Identifiable {
  public enum Kind: Hashable, Sendable {
    /// The first WATCH of a run of them.
    case watch
    /// An ENTER the platform took.
    case enter
    /// An ENTER the platform refused.
    case refused
  }

  public let kind: Kind
  /// Start of the candle the decision fell in.
  public let candle: Date
  /// That candle's close, where the mark sits.
  public let price: Double

  public var id: ChartEvent { self }

  /// Marks for `decisions` as the bot serves them (oldest first) on `candles`. The strategy's own
  /// decisions that change something count (an IGNORE or HOLD between two WATCH bars, or a WATCH
  /// whose checks changed, does not start a new watch, as on the Mac's chart): a WATCH is marked
  /// where a watch starts, an ENTER where a run of the same admission starts; one candle carries
  /// at most one mark of each kind; a decision outside every candle is not marked.
  public static func make(_ decisions: [DecisionV1], candles: [Candle]) -> [ChartEvent] {
    make(decisions, candles: candles, drawn: candles)
  }

  /// The same marks on candles drawn back to back (`ChartSeries.gapless`): a decision is found in
  /// its real candle (`candles`) and marked at the drawn candle of the same index (`drawn`).
  public static func make(_ decisions: [DecisionV1], candles: [Candle], drawn: [Candle]) -> [ChartEvent] {
    let strategy = decisions.filter { !$0.observer && $0.action != .ignore && $0.action != .hold }
    var events: [ChartEvent] = []
    var previous: Kind?
    for decision in strategy {
      let kind = kind(decision)
      defer { previous = kind }
      // A WATCH, ENTER or refused ENTER right after one of its own kind continues it.
      guard let kind, kind != previous,
        let index = candles.firstIndex(where: { $0.start <= decision.at.date && decision.at.date < $0.end }),
        drawn.indices.contains(index)
      else { continue }
      let event = ChartEvent(kind: kind, candle: drawn[index].start, price: candles[index].close)
      if !events.contains(event) { events.append(event) }
    }
    return events
  }

  static func kind(_ decision: DecisionV1) -> Kind? {
    switch decision.action {
    case .watch: .watch
    case .enter:
      switch decision.admission {
      case .taken: .enter
      case .refused: .refused
      // Never evaluated (an observer's) or without an admission: nothing to claim on the chart.
      case .notEvaluated, .notApplicable: nil
      }
    case .ignore, .hold, .exit: nil
    }
  }
}
