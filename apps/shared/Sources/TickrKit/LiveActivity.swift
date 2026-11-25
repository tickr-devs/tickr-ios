import Foundation

// The iPhone Live Activity of a trading day (docs/api.md, "Live Activity"): the bot starts,
// updates and ends it by push only; the app never starts one. One definition for the app (which
// reports the activity's push tokens) and the widget extension (which draws it). The
// ActivityKit conformance is in LiveActivity+ActivityKit.swift.

/// The activity's attributes: none. The bot's push names this type (`attributes-type`, config
/// `[live_activity] attributes_type`), so its name never changes.
public struct TickrActivityAttributes: Codable, Hashable, Sendable {
  public init() {}

  /// What the bot pushes as `content-state` (mockup v138): snake_case keys, every key present.
  /// A state this app does not know fails to decode, so the activity keeps what it showed rather
  /// than guess.
  public struct ContentState: Codable, Hashable, Sendable {
    public let state: ActivityState
    /// The day's result as the apps show it, in cents.
    public let dayPnlCents: Int
    public let positions: [ActivityPosition]
    /// Unix seconds of the last broker read with every stop verified; nil before the first.
    public let stopsConfirmedAt: Int?
    /// Paused: the entry block's cause; alarm: the unprotected fence's reason code.
    public let reasonCode: String?
    /// Alarm: the first position whose stop is not verified.
    public let alarmSymbol: String?

    enum CodingKeys: String, CodingKey {
      case state, positions
      case dayPnlCents = "day_pnl_cents"
      case stopsConfirmedAt = "stops_confirmed_at"
      case reasonCode = "reason_code"
      case alarmSymbol = "alarm_symbol"
    }

    public init(
      state: ActivityState, dayPnlCents: Int, positions: [ActivityPosition], stopsConfirmedAt: Int?,
      reasonCode: String?, alarmSymbol: String?
    ) {
      self.state = state
      self.dayPnlCents = dayPnlCents
      self.positions = positions
      self.stopsConfirmedAt = stopsConfirmedAt
      self.reasonCode = reasonCode
      self.alarmSymbol = alarmSymbol
    }

    public init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      state = try c.decode(ActivityState.self, forKey: .state)
      dayPnlCents = try c.decode(Int.self, forKey: .dayPnlCents)
      positions = try c.decode([ActivityPosition].self, forKey: .positions)
      stopsConfirmedAt = try c.decodeNullable(Int.self, forKey: .stopsConfirmedAt)
      reasonCode = try c.decodeNullable(String.self, forKey: .reasonCode)
      alarmSymbol = try c.decodeNullable(String.self, forKey: .alarmSymbol)
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(state, forKey: .state)
      try c.encode(dayPnlCents, forKey: .dayPnlCents)
      try c.encode(positions, forKey: .positions)
      try c.encodeNullable(stopsConfirmedAt, forKey: .stopsConfirmedAt)
      try c.encodeNullable(reasonCode, forKey: .reasonCode)
      try c.encodeNullable(alarmSymbol, forKey: .alarmSymbol)
    }

    /// The day's result in dollars.
    public var dayResult: Decimal { ActivityPosition.dollars(cents: dayPnlCents) }

    /// When the broker last confirmed every stop.
    public var stopsConfirmed: Date? {
      stopsConfirmedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    /// Why entries are paused, in the person's language: a cause this app does not know reads as
    /// "Other reason" (and goes to the diagnostics log); nil when the bot sent none.
    public var pauseReason: String? {
      reasonCode.map { ApiText.blockCause($0) ?? ApiText.otherReason($0) }
    }
  }
}

/// What the activity says about the bot: open with every stop verified, entries paused, a stop
/// not verified (the one alarm), or flat at the end.
public enum ActivityState: String, Codable, Sendable, CaseIterable {
  case open, paused, alarm, flat
}

/// One open position on the activity. Prices are the bot's decimal strings; `target` is always
/// nil until the bot has a profit target.
public struct ActivityPosition: Codable, Hashable, Sendable {
  public let symbol: String
  /// The broker's last price; nil while its account read lacks it or is stale.
  public let last: Decimal?
  /// The stop's price; nil without a stop.
  public let stop: Decimal?
  public let target: Decimal?
  /// The broker's unrealized result, in cents; nil with `last`.
  public let unrealizedCents: Int?

  enum CodingKeys: String, CodingKey {
    case symbol, last, stop, target
    case unrealizedCents = "unrealized_cents"
  }

  public init(symbol: String, last: Decimal?, stop: Decimal?, target: Decimal?, unrealizedCents: Int?) {
    self.symbol = symbol
    self.last = last
    self.stop = stop
    self.target = target
    self.unrealizedCents = unrealizedCents
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try c.decode(String.self, forKey: .symbol)
    last = try c.decodeNullable(DecimalString.self, forKey: .last)?.value
    stop = try c.decodeNullable(DecimalString.self, forKey: .stop)?.value
    target = try c.decodeNullable(DecimalString.self, forKey: .target)?.value
    unrealizedCents = try c.decodeNullable(Int.self, forKey: .unrealizedCents)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(symbol, forKey: .symbol)
    try c.encodeNullable(last.map(Self.text), forKey: .last)
    try c.encodeNullable(stop.map(Self.text), forKey: .stop)
    try c.encodeNullable(target.map(Self.text), forKey: .target)
    try c.encodeNullable(unrealizedCents, forKey: .unrealizedCents)
  }

  /// The unrealized result in dollars.
  public var unrealized: Decimal? { unrealizedCents.map(Self.dollars(cents:)) }

  /// Where `last` sits between the stop (0) and the target (1), kept within the bar; nil without
  /// all three prices or with a target not above the stop.
  public var progress: Double? {
    guard let last, let stop, let target, target > stop else { return nil }
    let share = (last - stop) / (target - stop)
    return min(max(NSDecimalNumber(decimal: share).doubleValue, 0), 1)
  }

  /// Cents in a dollar.
  static let centsPerDollar: Decimal = 100

  static func dollars(cents: Int) -> Decimal { Decimal(cents) / centsPerDollar }

  /// A price as the bot writes it ("12.48"): Decimal's own text, the same in every locale.
  static func text(_ price: Decimal) -> String { price.description }
}
