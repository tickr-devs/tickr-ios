import Foundation

/// A symbol's bars of one New York day as every screen reads them: the Chart, the Overview's and
/// the Positions tab's position cards and the Symbols detail's price line. Owner rule: one source
/// of truth per value, so two screens never show two prices for one moment.
///
/// Today (the latest session) comes from market data: GET /chart, range 1d, every session, out of
/// the API's one cache per symbol and day, which every reader of the symbol shares (one provider
/// read per `[chart] live_ttl_seconds` whoever asks). A recorded day comes from the bot's capture
/// (GET /bars), the only record of it; so does today while market data is unavailable (503: the
/// chart is off or not ready) or before its 04:00 pre-market (the latest session is still the day
/// before). Display only: the bot never reads these.
public enum DayBars: Hashable, Sendable {
  /// Today from market data, in the asked interval.
  case marketData(ChartV1)
  /// A recorded day, or today without market data: the bot's captured M1 bars.
  case capture(BarsV1)

  /// HTTP status of GET /chart while market data is off or not ready (docs/api.md).
  static let unavailable = 503

  /// The bars of `symbol` on `day`; `today` is the bot's New York date. `interval` is the
  /// candle length asked of market data (the capture is always one minute).
  public static func read(
    _ client: APIClient, symbol: String, day: WireDate, today: WireDate, interval: Timeframe = .m1
  ) async throws -> DayBars {
    if day == today {
      do {
        let chart = try await client.chart(symbol: symbol, interval: interval, range: .oneDay)
        if chart.holdsSession(of: day) { return .marketData(chart) }
      } catch APIError.refused(let status, _, _) where status == unavailable {
        // Market data is off or not ready: the capture below.
      }
    }
    return .capture(try await client.bars(symbol: symbol, day: day))
  }

  /// The bars oldest first, as one-minute bars or the asked interval's candles.
  public var bars: [BarV1] {
    switch self {
    case .marketData(let chart):
      chart.bars.map { BarV1(start: $0.start, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
    case .capture(let captured): captured.bars
    }
  }

  /// Start of the newest bar.
  public var newestStart: Date? {
    switch self {
    case .marketData(let chart): chart.bars.last?.start.date
    case .capture(let captured): captured.bars.last?.start.date
    }
  }

  /// What the answer still waits for while the chart's budget fills it; nil when complete.
  public var pending: ChartPendingV1? {
    if case .marketData(let chart) = self { return chart.pending }
    return nil
  }
}
