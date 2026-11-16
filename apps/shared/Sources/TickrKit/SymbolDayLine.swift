import Foundation

/// A symbol's price line today for the Symbols detail (mockup v101): the close of every one-minute
/// bar, oldest first, and the previous close it is measured against.
///
/// The bars come from GET /bars, the minute bars the bot already stored for its watched and
/// candidate symbols, so showing a line costs no market data request. Only when the bot stored
/// none for the symbol does one GET /chart read of today's one-minute candles follow, for the one
/// symbol the person selected; the API serves it through its own chart request budget and cache.
public struct SymbolDayLine: Hashable, Sendable {
  /// Percent per whole (unit factor).
  static let percent: Decimal = 100

  public let closes: [Decimal]
  public let previousClose: Decimal?

  public init(closes: [Decimal], previousClose: Decimal?) {
    self.closes = closes
    self.previousClose = previousClose
  }

  /// The line of `symbol` on `day`: stored bars first, the chart read only without them and only
  /// for today (the chart serves the latest session). Nil when neither has a bar or the reads
  /// fail; the detail then shows no line, never an invented one.
  public static func read(
    _ symbol: String, day: WireDate, today: WireDate, previousClose: Decimal?, client: APIClient
  ) async -> SymbolDayLine? {
    if let stored = try? await client.bars(symbol: symbol, day: day), !stored.bars.isEmpty {
      return SymbolDayLine(closes: stored.bars.map(\.close.value), previousClose: previousClose)
    }
    guard day == today, !Task.isCancelled,
      let chart = try? await client.chart(symbol: symbol, interval: .m1, range: .oneDay),
      !chart.bars.isEmpty else { return nil }
    return SymbolDayLine(closes: chart.bars.map(\.close.value), previousClose: previousClose)
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
