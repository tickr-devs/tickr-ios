import Foundation

// The "Last entry size" block of the Risk room card, the same on both apps (mockup v115): what
// the latest sized decision bought, the shares each sizing limit allowed, and which limit set the
// size. Pure functions over GET /watching's `latest_size`; the limits' figures are the bot's own,
// worked out from what its strategy recorded. Only the example for a day with no entry is worked
// out here, from the configured limits, and it says so.

/// How amounts read in the block. The apps pass `SizeText.money` (TickrDesign's `Money`;
/// TickrKit does not import the design module), so every amount goes through the one money rule.
public struct SizeText: Sendable {
  /// An amount of money: "$2,500.00".
  public let usd: @Sendable (Decimal) -> String
  /// A price per share, at its tick: "$0.7100", "$21.70".
  public let price: @Sendable (Decimal) -> String
  /// A number of shares: "3,521".
  public let shares: @Sendable (Decimal) -> String

  public init(
    usd: @escaping @Sendable (Decimal) -> String,
    price: @escaping @Sendable (Decimal) -> String,
    shares: @escaping @Sendable (Decimal) -> String
  ) {
    self.usd = usd
    self.price = price
    self.shares = shares
  }
}

/// The configured limits the example of a day with no entry is sized with (GET /settings) and
/// the bot's daily room (GET /status), if it reported one.
public struct SizingLimits: Equatable, Sendable {
  public let plannedLossUsd: Decimal
  public let notionalCapUsd: Decimal
  public let dailyRoomUsd: Decimal?

  public init(plannedLossUsd: Decimal, notionalCapUsd: Decimal, dailyRoomUsd: Decimal?) {
    self.plannedLossUsd = plannedLossUsd
    self.notionalCapUsd = notionalCapUsd
    self.dailyRoomUsd = dailyRoomUsd
  }
}

/// The block as both apps draw it.
public struct EntrySizing: Equatable, Sendable {
  /// One sizing limit: what it is, how many shares it allows, and how much of that the size used.
  public struct Limit: Equatable, Sendable, Identifiable {
    public let id: SizeBinding
    /// "Notional cap $2,500.00 ÷ $0.7100".
    public let label: String
    /// "3,521 sh".
    public let allows: String
    /// The share of this limit's allowance the size used, 0...1: the limit that set the size is full.
    public let used: Double
    /// Whether this limit set the size.
    public let binds: Bool
  }

  /// What the caption under the limits says.
  public enum Tone: Equatable, Sendable {
    /// A limit set the size of a real entry.
    case bound
    /// The example's limit, for a day with no entry.
    case example
    /// The record does not prove which limit set it (an older record): the bot's cause.
    case unproven
  }

  /// The block's title.
  public static var title: String { String(localized: L10n.sizingTitle) }
  /// The badge beside `meta`.
  public static var badge: String { String(localized: L10n.sizingBadge) }

  /// Price of the example stock shown when nothing was sized today, in USD (mockup v115).
  public static let examplePrice: Decimal = 10
  /// Stop distance of the example stock, in USD per share (mockup v115).
  public static let exampleStop = Decimal(sign: .plus, exponent: -2, significand: 25)

  /// "IQ · 10:31"; nil for a day with no entry.
  public let meta: String?
  /// "IQ · 3,521 shares · $2,499.91 at $0.7100", or "No entry sized today".
  public let line: String
  /// "Each limit allows:" or the example's; nil when there are no limits to show.
  public let lead: String?
  public let limits: [Limit]
  /// "Size set by: notional cap $2,500.00"; nil when there is nothing to say.
  public let caption: String?
  public let tone: Tone

  /// The block for the latest sized decision, or, when there is none, for the example stock
  /// sized with `configured` (just the line when the limits are not known either).
  public init(size: LatestSizeV1?, configured: SizingLimits?, text: SizeText) {
    if let size {
      self = Self.entry(size, text: text)
    } else {
      self = Self.example(configured, text: text)
    }
  }

  private init(meta: String?, line: String, lead: String?, limits: [Limit], caption: String?, tone: Tone) {
    self.meta = meta
    self.line = line
    self.lead = lead
    self.limits = limits
    self.caption = caption
    self.tone = tone
  }

  private static func entry(_ size: LatestSizeV1, text: SizeText) -> EntrySizing {
    let quantity = size.quantity.value
    let shares = text.shares(quantity)
    let line = size.price.map { price in
      String(localized: L10n.sizingLine(size.symbol, shares, text.usd(quantity * price.value), text.price(price.value)))
    } ?? String(localized: L10n.sizingLineNoPrice(size.symbol, shares))
    let meta = String(localized: L10n.sizingMeta(size.symbol, ClockText.minutes(size.at.date)))
    let limits = size.limits.map { limit in
      row(Allowance(kind: limit.limit, usd: limit.limitUsd.value, perShare: limit.perShareUsd.value,
        shares: limit.shares.value), size: quantity, binds: limit.limit == size.binding, text: text)
    }
    let caption: String?
    if let binding = size.binding {
      if let bound = size.limits.first(where: { $0.limit == binding }) {
        caption = String(localized: L10n.sizingSetBy(name(binding), text.usd(bound.limitUsd.value)))
      } else {
        caption = String(localized: L10n.sizingSetByNoAmount(name(binding)))
      }
    } else {
      caption = size.bindingCauseText
    }
    return EntrySizing(meta: meta, line: line, lead: limits.isEmpty ? nil : String(localized: L10n.sizingLead),
      limits: limits, caption: caption, tone: size.binding == nil ? .unproven : .bound)
  }

  /// The example stock sized with the configured limits, the way the strategies size: each limit
  /// over its per-share figure, rounded down; the daily room first when it is below the planned loss.
  private static func example(_ configured: SizingLimits?, text: SizeText) -> EntrySizing {
    let line = String(localized: L10n.sizingNone)
    guard let configured else {
      return EntrySizing(meta: nil, line: line, lead: nil, limits: [], caption: nil, tone: .example)
    }
    var allowed = [
      Allowance(kind: .plannedLoss, usd: configured.plannedLossUsd, perShare: exampleStop),
      Allowance(kind: .notionalCap, usd: configured.notionalCapUsd, perShare: examplePrice),
    ]
    if let room = configured.dailyRoomUsd {
      allowed.append(Allowance(kind: .dailyRoom, usd: max(room, 0), perShare: exampleStop))
    }
    guard let size = allowed.map(\.shares).min() else {
      return EntrySizing(meta: nil, line: line, lead: nil, limits: [], caption: nil, tone: .example)
    }
    let room = allowed.first { $0.kind == .dailyRoom }
    let roomBinds = room.map { $0.shares == size && $0.usd < configured.plannedLossUsd } == true
    let binding = roomBinds ? SizeBinding.dailyRoom : allowed.first(where: { $0.shares == size })?.kind ?? .plannedLoss
    let limits = allowed.map { row($0, size: size, binds: $0.kind == binding, text: text) }
    let bound = allowed.first { $0.kind == binding }?.usd ?? 0
    return EntrySizing(meta: nil, line: line,
      lead: String(localized: L10n.sizingExampleLead(text.usd(examplePrice), text.usd(exampleStop))),
      limits: limits,
      caption: String(localized: L10n.sizingWouldBeSetBy(name(binding), text.usd(bound), text.shares(size))),
      tone: .example)
  }

  /// One limit's figures: its amount over a per-share figure allows `shares`.
  private struct Allowance {
    let kind: SizeBinding
    let usd: Decimal
    let perShare: Decimal
    let shares: Decimal

    init(kind: SizeBinding, usd: Decimal, perShare: Decimal, shares: Decimal) {
      self.kind = kind
      self.usd = usd
      self.perShare = perShare
      self.shares = shares
    }

    /// The shares the strategies would size: the amount over the per-share figure, rounded down.
    init(kind: SizeBinding, usd: Decimal, perShare: Decimal) {
      self.init(kind: kind, usd: usd, perShare: perShare, shares: EntrySizing.floor(usd / perShare))
    }
  }

  private static func row(_ allowance: Allowance, size: Decimal, binds: Bool, text: SizeText) -> Limit {
    let kind = allowance.kind, usd = allowance.usd, perShare = allowance.perShare, shares = allowance.shares
    let label: LocalizedStringResource = switch kind {
    case .plannedLoss: L10n.sizingRowPlannedLoss(text.usd(usd), text.price(perShare))
    case .notionalCap: L10n.sizingRowNotionalCap(text.usd(usd), text.price(perShare))
    case .dailyRoom: L10n.sizingRowDailyRoom(text.usd(usd), text.price(perShare))
    }
    // A limit allowing nothing is full when it set the size, empty otherwise.
    let used = shares > 0 ? NSDecimalNumber(decimal: max(size, 0) / shares).doubleValue : (binds ? 1 : 0)
    return Limit(id: kind, label: String(localized: label), allows: String(localized: L10n.sizingShares(text.shares(shares))),
      used: min(max(used, 0), 1), binds: binds)
  }

  /// A limit's name inside a sentence ("notional cap").
  private static func name(_ kind: SizeBinding) -> String {
    switch kind {
    case .plannedLoss: String(localized: L10n.sizingNamePlannedLoss)
    case .notionalCap: String(localized: L10n.sizingNameNotionalCap)
    case .dailyRoom: String(localized: L10n.sizingNameDailyRoom)
    }
  }

  /// Rounded down to whole shares.
  fileprivate static func floor(_ value: Decimal) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, 0, .down)
    return output
  }
}
