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

  /// Nil without a quote, or when the stream's last delivery (`stream.receivedAt`, GET /quotes
  /// `stream_received_at`) is older at `now` (the bot's clock) than `maxAgeSeconds` (GET /settings
  /// `live_quote_max_age_seconds`; nil, from an older API, means none is live). While the stream
  /// delivers, a symbol's newest quote is its market however long it has not changed (the bot
  /// replaces it on every change and drops it when it unsubscribes the symbol); when the bot or its
  /// stream stops, deliveries stop and nothing is shown as live. From a bot without
  /// `stream_received_at` the quote's own age stands in for it. A quote received before the
  /// stream last came up (`streamConnectedAt`) predates a gap and is never live, however fresh
  /// other symbols' quotes keep the stream.
  public init?(quote: LiveQuoteV1?, now: Date, maxAgeSeconds: Decimal?, stream: StreamTimes = StreamTimes()) {
    guard let quote, let maxAgeSeconds else { return nil }
    if let connected = stream.connectedAt, quote.receivedAt.date < connected { return nil }
    let streamReceivedAt = stream.receivedAt
    let age = now.timeIntervalSince(streamReceivedAt ?? quote.quotedAt.date)
    guard age <= NSDecimalNumber(decimal: maxAgeSeconds).doubleValue else { return nil }
    bid = quote.bid.value
    ask = quote.ask.value
    quotedAt = quote.quotedAt.date
  }

  /// (bid − entry) × quantity, in dollars.
  public func unrealized(entry: Decimal, quantity: Decimal) -> Decimal { (bid - entry) * quantity }
}

/// When the bot's quote stream last delivered any quote and last came up (GET /quotes
/// `stream_received_at`, `stream_connected_at`); nil each from an older bot.
public struct StreamTimes: Hashable, Sendable {
  public let receivedAt: Date?
  public let connectedAt: Date?

  public init(receivedAt: Date? = nil, connectedAt: Date? = nil) {
    self.receivedAt = receivedAt
    self.connectedAt = connectedAt
  }
}

/// The bot's live quotes as the app last read them (GET /quotes), by symbol: the one place both
/// apps take a live price from. A failed read empties it, so nothing older than the last good
/// answer is ever shown as live.
@MainActor
@Observable
public final class LiveQuotes {
  /// The newest quote of every symbol on the bot's stream, by symbol.
  public private(set) var bySymbol: [String: LiveQuoteV1] = [:]
  /// When the bot's stream last delivered any quote and last came up (GET /quotes).
  public private(set) var stream = StreamTimes()
  /// Counts `clear()` calls: a read that started before one is dropped when it answers, so a late
  /// answer from the server the app left never shows as the new one's quotes.
  @ObservationIgnored private var epoch = 0

  public init() {}

  /// Read GET /quotes once with `client`.
  public func refresh(_ client: APIClient) async {
    let epoch = self.epoch
    do {
      let read = try await client.quotes()
      // Cleared meanwhile (another server): this answer belongs to the one before.
      guard epoch == self.epoch else { return }
      let fresh = Dictionary(read.quotes.quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, newer in newer })
      // Unchanged quotes redraw nothing.
      if fresh != bySymbol { bySymbol = fresh }
      let times = StreamTimes(receivedAt: read.quotes.streamReceivedAt?.date, connectedAt: read.quotes.streamConnectedAt?.date)
      if times != stream { stream = times }
    } catch is CancellationError {
      return
    } catch {
      guard epoch == self.epoch else { return }
      if !bySymbol.isEmpty { bySymbol = [:] }
      if stream != StreamTimes() { stream = StreamTimes() }
    }
  }

  /// Forget every quote (another bot address, a stopped app).
  public func clear() {
    epoch += 1
    bySymbol = [:]
    stream = StreamTimes()
  }

  /// The live price of `symbol` at `now` (the bot's clock) under `settings`; nil when there is
  /// none (see `LivePrice`).
  public func price(_ symbol: String, now: Date, settings: SettingsV1?) -> LivePrice? {
    LivePrice(quote: bySymbol[symbol], now: now, maxAgeSeconds: settings?.liveQuoteMaxAgeSeconds?.value,
      stream: stream)
  }

  /// Seconds between two reads under `settings`; nil when the API has no /quotes (then there is
  /// nothing to read).
  public static func pollSeconds(_ settings: SettingsV1?) -> Double? {
    settings?.quotesPollSeconds.map { NSDecimalNumber(decimal: $0.value).doubleValue }
  }
}
