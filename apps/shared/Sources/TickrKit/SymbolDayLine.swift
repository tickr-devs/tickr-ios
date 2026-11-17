import Foundation

/// A symbol's price line today for the Symbols detail (mockup v101): the close of every one-minute
/// bar, oldest first, and the previous close it is measured against.
///
/// The bars come from where every screen reads a day's bars (`DayBars`), so the line agrees with
/// the Chart and the position cards: today from market data (one GET /chart read for the one
/// symbol the person selected, through the chart's own budget and the cache every reader of the
/// symbol shares), a recorded day from the bot's capture.
public struct SymbolDayLine: Hashable, Sendable {
  /// Percent per whole (unit factor).
  static let percent: Decimal = 100

  public let closes: [Decimal]
  public let previousClose: Decimal?

  public init(closes: [Decimal], previousClose: Decimal?) {
    self.closes = closes
    self.previousClose = previousClose
  }

  /// The line of `symbol` on `day` (`DayBars`). Nil when it has no bar or the read fails; the
  /// detail then shows no line, never an invented one.
  public static func read(
    _ symbol: String, day: WireDate, today: WireDate, previousClose: Decimal?, client: APIClient
  ) async -> SymbolDayLine? {
    guard let read = try? await DayBars.read(client, symbol: symbol, day: day, today: today), !read.bars.isEmpty else {
      return nil
    }
    return SymbolDayLine(closes: read.bars.map(\.close.value), previousClose: previousClose)
  }

  /// The previous close behind `price` and its change in percent; nil without either.
  public static func previousClose(price: DecimalString?, changePct: DecimalString?) -> Decimal? {
    guard let price = price?.value, let change = changePct?.value, percent + change != 0 else { return nil }
    return price * percent / (percent + change)
  }

  /// The closes and the previous close as plot values.
  public var plotted: (closes: [Double], previousClose: Double?) {
    let value = { (decimal: Decimal) in NSDecimalNumber(decimal: decimal).doubleValue }
    return (closes.map(value), previousClose.map(value))
  }
}
