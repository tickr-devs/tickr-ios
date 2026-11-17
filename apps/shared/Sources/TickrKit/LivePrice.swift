import Foundation
import Observation

/// A symbol's live price: the bid of the newest quote the bot holds on its quote stream, what a
/// long position would sell at. The bot writes its quotes file within half a second of a change
/// and the apps read it every second (GET /quotes, `LiveQuotes`), so it follows the market within
/// about two seconds, where a captured one-minute bar is up to two minutes behind. Display only;
/// the broker's numbers stay the truth.
public struct LivePrice: Hashable, Sendable {
  /// The quote's bid.
  public let bid: Decimal
  /// The quote's ask.
  public let ask: Decimal
  /// When the provider quoted it.
  public let quotedAt: Date

  /// Nil without a quote, or when it is older at `now` (the bot's clock) than `maxAgeSeconds`
  /// (GET /settings `live_quote_max_age_seconds`; nil, from an older API, means none is live): a
  /// thin stock's last quote can be minutes old while the stream is healthy, and a quote stops
  /// changing when the bot or its stream stops, so an old one is never shown as live.
  public init?(quote: LiveQuoteV1?, now: Date, maxAgeSeconds: Decimal?) {
    guard let quote, let maxAgeSeconds else { return nil }
    let age = now.timeIntervalSince(quote.quotedAt.date)
    guard age <= NSDecimalNumber(decimal: maxAgeSeconds).doubleValue else { return nil }
    bid = quote.bid.value
    ask = quote.ask.value
    quotedAt = quote.quotedAt.date
  }

  /// (bid − entry) × quantity, in dollars.
  public func unrealized(entry: Decimal, quantity: Decimal) -> Decimal { (bid - entry) * quantity }
}

/// The bot's live quotes as the app last read them (GET /quotes), by symbol: the one place both
/// apps take a live price from. A failed read empties it, so nothing older than the last good
/// answer is ever shown as live.
@MainActor
@Observable
public final class LiveQuotes {
  /// The newest quote of every symbol on the bot's stream, by symbol.
  public private(set) var bySymbol: [String: LiveQuoteV1] = [:]

  public init() {}

  /// Read GET /quotes once with `client`.
  public func refresh(_ client: APIClient) async {
    do {
      let read = try await client.quotes()
      let fresh = Dictionary(read.quotes.quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, newer in newer })
      // Unchanged quotes redraw nothing.
      if fresh != bySymbol { bySymbol = fresh }
    } catch is CancellationError {
      return
    } catch {
      if !bySymbol.isEmpty { bySymbol = [:] }
    }
  }

  /// Forget every quote (another bot address, a stopped app).
  public func clear() { bySymbol = [:] }

  /// The live price of `symbol` at `now` (the bot's clock) under `settings`; nil when there is
  /// none (see `LivePrice`).
  public func price(_ symbol: String, now: Date, settings: SettingsV1?) -> LivePrice? {
    LivePrice(quote: bySymbol[symbol], now: now, maxAgeSeconds: settings?.liveQuoteMaxAgeSeconds?.value)
  }

  /// Seconds between two reads under `settings`; nil when the API has no /quotes (then there is
  /// nothing to read).
  public static func pollSeconds(_ settings: SettingsV1?) -> Double? {
    settings?.quotesPollSeconds.map { NSDecimalNumber(decimal: $0.value).doubleValue }
  }
}
