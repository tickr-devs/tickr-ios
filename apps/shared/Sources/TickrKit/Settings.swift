import Foundation

// Swift mirror of settings-v1 (GET /settings) in src/tickr/api/contract.py: the numbers from
// config/bot.toml that the apps show. Read-only; they change by editing the file and restarting.

public struct RiskSettings: Codable, Hashable, Sendable {
  public let plannedLossUsd: DecimalString
  public let positionNotionalCapUsd: DecimalString
  public let maxDailyLossUsd: DecimalString
  public let maxOpenPositions: Int
  public let maxQuoteAgeSeconds: DecimalString
  /// Below this much daily room the bot takes no new entries.
  public let minDailyRoomUsd: DecimalString

  enum CodingKeys: String, CodingKey {
    case plannedLossUsd = "planned_loss_usd"
    case positionNotionalCapUsd = "position_notional_cap_usd"
    case maxDailyLossUsd = "max_daily_loss_usd"
    case maxOpenPositions = "max_open_positions"
    case maxQuoteAgeSeconds = "max_quote_age_seconds"
    case minDailyRoomUsd = "min_daily_room_usd"
  }
}

public struct SessionSettings: Codable, Hashable, Sendable {
  public let timezone: String
  public let lastEntryMinutesBeforeClose: Int
  public let flattenMinutesBeforeClose: Int
  public let halfDaysEnabled: Bool

  enum CodingKeys: String, CodingKey {
    case timezone
    case lastEntryMinutesBeforeClose = "last_entry_minutes_before_close"
    case flattenMinutesBeforeClose = "flatten_minutes_before_close"
    case halfDaysEnabled = "half_days_enabled"
  }
}

/// GET /settings.
public struct SettingsV1: Codable, Hashable, Sendable {
  public let environment: String
  public let activeStrategy: String
  /// Shadow strategies the config names; mirrored for the contract, not shown by the apps.
  public let observers: [String]
  public let risk: RiskSettings
  public let session: SessionSettings
  public let statusStaleSeconds: DecimalString
  public let pollSeconds: DecimalString
  /// Age of the last broker read, in seconds, past which the bot blocks new entries.
  public let brokerReadMaxAgeSeconds: DecimalString
  /// Age of the last broker read, in seconds, past which clients show it as late; below the block age.
  public let brokerReadWarnSeconds: DecimalString
  /// Oldest live position quote, in seconds, shown as the position's price (`LivePrice`); nil from
  /// an older API, and then no quote is live (added after version 1 shipped).
  public let liveQuoteMaxAgeSeconds: DecimalString?
  /// Seconds between two reads of GET /quotes; nil from an older API, which has none.
  public let quotesPollSeconds: DecimalString?
  /// Age, in seconds, past which the bot refuses a command as expired: how long the apps keep the
  /// idempotency key of a send whose answer was lost (`CommandKeys`); nil from an older API, and
  /// then they keep none.
  public let commandMaxAgeSeconds: DecimalString?
  public let apiVersion: Int
  /// Who decides entries: the active strategy's name and version (docs/api.md, "Decider"); nil with
  /// `deciderCause` (a code) when its file cannot be read, and nil from an older API.
  public let decider: DeciderV1?
  public let deciderCause: String?

  enum CodingKeys: String, CodingKey {
    case environment, observers, risk, session, decider
    case deciderCause = "decider_cause"
    case activeStrategy = "active_strategy"
    case statusStaleSeconds = "status_stale_seconds"
    case pollSeconds = "poll_seconds"
    case brokerReadMaxAgeSeconds = "broker_read_max_age_seconds"
    case brokerReadWarnSeconds = "broker_read_warn_seconds"
    case liveQuoteMaxAgeSeconds = "live_quote_max_age_seconds"
    case quotesPollSeconds = "quotes_poll_seconds"
    case commandMaxAgeSeconds = "command_max_age_seconds"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    environment = try c.decode(String.self, forKey: .environment)
    activeStrategy = try c.decode(String.self, forKey: .activeStrategy)
    observers = try c.decode([String].self, forKey: .observers)
    risk = try c.decode(RiskSettings.self, forKey: .risk)
    session = try c.decode(SessionSettings.self, forKey: .session)
    statusStaleSeconds = try c.decode(DecimalString.self, forKey: .statusStaleSeconds)
    pollSeconds = try c.decode(DecimalString.self, forKey: .pollSeconds)
    brokerReadMaxAgeSeconds = try c.decode(DecimalString.self, forKey: .brokerReadMaxAgeSeconds)
    brokerReadWarnSeconds = try c.decode(DecimalString.self, forKey: .brokerReadWarnSeconds)
    liveQuoteMaxAgeSeconds = try c.decodeIfPresent(DecimalString.self, forKey: .liveQuoteMaxAgeSeconds)
    quotesPollSeconds = try c.decodeIfPresent(DecimalString.self, forKey: .quotesPollSeconds)
    commandMaxAgeSeconds = try c.decodeIfPresent(DecimalString.self, forKey: .commandMaxAgeSeconds)
    decider = try c.decodeIfPresent(DeciderV1.self, forKey: .decider)
    deciderCause = try c.decodeIfPresent(String.self, forKey: .deciderCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(environment, forKey: .environment)
    try c.encode(activeStrategy, forKey: .activeStrategy)
    try c.encode(observers, forKey: .observers)
    try c.encode(risk, forKey: .risk)
    try c.encode(session, forKey: .session)
    try c.encode(statusStaleSeconds, forKey: .statusStaleSeconds)
    try c.encode(pollSeconds, forKey: .pollSeconds)
    try c.encode(brokerReadMaxAgeSeconds, forKey: .brokerReadMaxAgeSeconds)
    try c.encode(brokerReadWarnSeconds, forKey: .brokerReadWarnSeconds)
    try c.encodeNullable(liveQuoteMaxAgeSeconds, forKey: .liveQuoteMaxAgeSeconds)
    try c.encodeNullable(quotesPollSeconds, forKey: .quotesPollSeconds)
    try c.encodeNullable(commandMaxAgeSeconds, forKey: .commandMaxAgeSeconds)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encodeNullable(decider, forKey: .decider)
    try c.encodeNullable(deciderCause, forKey: .deciderCause)
  }
}

extension StatusResponseV1 {
  /// Whether the apps must read GET /settings (again) after this answer: none read yet, or the
  /// API restarted since `readFor` (the `apiStartedAt` of the answer they were read after), and a
  /// new release may have brought other settings. Settings were read once per launch before, so an
  /// app left open across a release never learned of a new one (the live quotes stayed off).
  public func needsSettings(_ settings: SettingsV1?, readFor: WireTime?) -> Bool {
    settings == nil || apiStartedAt != readFor
  }
}
