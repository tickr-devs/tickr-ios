import Foundation

// Swift mirror of settings-v1 (GET /settings) in src/aperture/api/contract.py: the numbers from
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
  public let observers: [String]
  public let risk: RiskSettings
  public let session: SessionSettings
  public let statusStaleSeconds: DecimalString
  public let pollSeconds: DecimalString
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, observers, risk, session
    case activeStrategy = "active_strategy"
    case statusStaleSeconds = "status_stale_seconds"
    case pollSeconds = "poll_seconds"
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
  }
}
