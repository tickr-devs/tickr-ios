import Foundation

/// A version's gross result through a day as a step line: the running sum of its trades' results
/// at each close, ending at the result the bot reports for the day. Used by the Lab chart "Today if
/// each version traded" for the active strategy's real trades and each observer's simulated ones.
public struct DayCurve: Equatable, Sendable {
  public struct Step: Equatable, Sendable {
    public let at: Date
    /// The running sum after this close.
    public let total: Decimal
  }

  /// Closes in time order.
  public let steps: [Step]
  /// Where the line ends: the reported day result when the bot gives one, else the running sum.
  public let end: Decimal
  /// False when the trade list is incomplete (the server cut it short); the line is then dashed.
  public let complete: Bool

  /// From closes and results, in any order.
  public init(closes: [(at: Date, result: Decimal)], reported: Decimal?, complete: Bool) {
    var total: Decimal = 0
    steps = closes.sorted { $0.at < $1.at }.map { close in
      total += close.result
      return Step(at: close.at, total: total)
    }
    end = reported ?? total
    self.complete = complete
  }

  /// An observer's simulated trades; nil when the bot could not simulate them (`tradesCause`).
  /// Trades the simulation did not take or finish (they carry a cause, no result) add nothing.
  public static func observer(_ observer: ObserverV1) -> DayCurve? {
    guard let trades = observer.trades else { return nil }
    let closes = trades.compactMap { trade -> (at: Date, result: Decimal)? in
      guard let at = trade.closedAt?.date, let result = trade.resultGrossUsd?.value else { return nil }
      return (at, result)
    }
    return DayCurve(closes: closes, reported: observer.resultGrossUSD?.value, complete: !observer.tradesTruncated)
  }

  /// The active strategy's closed trades of the day.
  public static func trades(_ trades: [DayTrade], reported: Decimal?) -> DayCurve {
    DayCurve(closes: trades.map { ($0.closedAt.date, $0.resultGrossUsd.value) }, reported: reported, complete: true)
  }
}
