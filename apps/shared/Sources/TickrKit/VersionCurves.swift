import Foundation

/// The running result of one strategy version through the day, trade by trade as each closed:
/// the trading strategy from its real trades, an observer from its simulated ones. Drawn
/// together, they answer "what if each version had traded today".
public struct VersionCurve: Hashable, Sendable, Identifiable {
  /// The running total right after a trade closed.
  public struct Point: Hashable, Sendable {
    public let at: Date
    public let total: Decimal

    public init(at: Date, total: Decimal) {
      self.at = at
      self.total = total
    }
  }

  public let name: String
  public let version: String
  /// True for an observer (simulated, never trades); false for the trading strategy.
  public let observer: Bool
  /// Oldest first; empty when nothing closed.
  public let points: [Point]
  /// False when some trades are missing from the line: a simulated trade without a close or a
  /// result, or a list the server cut short. The line then never claims a total.
  public let complete: Bool
  /// The day's total as the bot reports it, when it reports one apart from the trades.
  public let reported: Decimal?
  /// When the version started watching that day (an observer added at a restart); nil: all day.
  public var since: Date?
  /// The row's name: "v3 · active", "v3 · rel vol 1.5×" (ObserverLabel).
  public var label: String = ""
  /// Under the row: since when it watched ("watching since 15:08 · no entries yet") and the
  /// symbols the trading strategy skipped; empty for none.
  public var notes: [String] = []

  public var id: String { "\(observer) \(name) \(version)" }
  /// The day's total so far; nil when the line is incomplete.
  public var total: Decimal? { complete ? reported ?? points.last?.total ?? 0 : nil }

  /// The line's corners from `start` to `end`: zero from the start (or from when the version
  /// started watching, when later), each close, then flat to the end (or the last close, when
  /// later).
  public func line(start: Date, end: Date) -> [Point] {
    let from = since.map { max(start, $0) } ?? start
    let last = points.last
    return [Point(at: min(from, last?.at ?? from), total: 0)] + points
      + [Point(at: max(end, last?.at ?? from), total: last?.total ?? 0)]
  }

  /// The trading strategy's line from its closed trades of the day; its total is the bot's own
  /// day result (`total`, the status's `result_today_gross_usd`), never re-summed here.
  public static func active(name: String, version: String, trades: [Trade], total: Decimal) -> VersionCurve {
    let closes = trades.map { (at: $0.closedAt.date, result: Optional($0.resultUsd.value)) }
    let curve = make(name: name, version: version, observer: false, closes: closes, truncated: false)
    var line = VersionCurve(name: name, version: version, observer: false, points: curve.points,
      complete: curve.complete, reported: total)
    line.label = ObserverLabel.active(name)
    return line
  }

  /// An observer's line from its simulated trades; nil when the bot could not list them.
  /// `traded`: the symbols the trading strategy traded or holds that day, for the note on the
  /// symbols it skipped; nil leaves that note out.
  public static func simulated(_ observer: ObserverV1, traded: Set<String>? = nil) -> VersionCurve? {
    guard let trades = observer.trades else { return nil }
    // An ENTER that never became a simulated trade (inside an earlier one, no bars) has no close.
    let closes = trades.compactMap { trade in
      trade.closedAt.map { (at: $0.date, result: trade.resultGrossUsd?.value) }
    }
    let curve = make(name: observer.name, version: observer.version, observer: true, closes: closes,
      truncated: observer.tradesTruncated)
    // The day's total is the bot's own simulated result, which may differ from the sum of the
    // listed trades by rounding; nil (unknown) when the bot has none.
    var line = VersionCurve(name: curve.name, version: curve.version, observer: true, points: curve.points,
      complete: curve.complete && observer.resultGrossUSD != nil, reported: observer.resultGrossUSD?.value)
    line.since = observer.watchingSince?.date
    line.label = ObserverLabel.observer(observer)
    line.notes = [ObserverLabel.since(observer),
      traded.flatMap { ObserverLabel.skipped(ObserverSummary(observer, traded: $0)) }].compactMap { $0 }
    return line
  }

  static func make(
    name: String, version: String, observer: Bool, closes: [(at: Date, result: Decimal?)], truncated: Bool
  ) -> VersionCurve {
    var total: Decimal = 0
    var points: [Point] = []
    var complete = !truncated
    for close in closes.sorted(by: { $0.at < $1.at }) {
      guard let result = close.result else {
        complete = false
        continue
      }
      total += result
      points.append(Point(at: close.at, total: total))
    }
    return VersionCurve(name: name, version: version, observer: observer, points: points, complete: complete,
      reported: nil)
  }
}
