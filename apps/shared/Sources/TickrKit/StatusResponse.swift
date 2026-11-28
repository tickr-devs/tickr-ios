import Foundation

/// GET /status. Always this shape; `status` is nil when the bot's file is missing or bad.
public struct StatusResponseV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let status: StatusV1?
  public let ageSeconds: DecimalString?
  public let stale: Bool
  public let unavailableCause: String?
  /// The codes of `unavailableCause` (added after version 1 shipped: empty from an older API).
  public let unavailableCauseCodes: [ReasonV1]
  public let summary: String
  public let pollSeconds: DecimalString
  public let apiVersion: Int
  public let apiStartedAt: WireTime? // the API's start: /settings are read again on a change (nil from an older API)
  /// When the bot is meant to run by its trading calendar (added after version 1 shipped); nil
  /// when the calendar cannot say (`scheduleCause`) or from an older API (`scheduleSent`).
  public let schedule: BotScheduleV1?
  public let scheduleCause: String?
  public let scheduleCauseCodes: [ReasonV1]
  /// Whether the API sent the schedule's keys (an older one sends none), so they round-trip.
  public let scheduleSent: Bool

  enum CodingKeys: String, CodingKey {
    case status, stale, summary
    case apiStartedAt = "api_started_at"
    case servedAt = "served_at"
    case ageSeconds = "age_seconds"
    case unavailableCause = "unavailable_cause"
    case pollSeconds = "poll_seconds"
    case apiVersion = "api_version"
    case unavailableCauseCodes = "unavailable_cause_codes"
    case schedule
    case scheduleCause = "schedule_cause"
    case scheduleCauseCodes = "schedule_cause_codes"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    status = try c.decodeNullable(StatusV1.self, forKey: .status)
    ageSeconds = try c.decodeNullable(DecimalString.self, forKey: .ageSeconds)
    stale = try c.decode(Bool.self, forKey: .stale)
    unavailableCause = try c.decodeNullable(String.self, forKey: .unavailableCause)
    unavailableCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .unavailableCauseCodes) ?? []
    summary = try c.decode(String.self, forKey: .summary)
    pollSeconds = try c.decode(DecimalString.self, forKey: .pollSeconds)
    apiStartedAt = try c.decodeIfPresent(WireTime.self, forKey: .apiStartedAt)
    scheduleSent = c.contains(.schedule)
    schedule = try c.decodeIfPresent(BotScheduleV1.self, forKey: .schedule)
    scheduleCause = try c.decodeIfPresent(String.self, forKey: .scheduleCause)
    scheduleCauseCodes = try c.decodeIfPresent([ReasonV1].self, forKey: .scheduleCauseCodes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(servedAt, forKey: .servedAt)
    try c.encodeNullable(status, forKey: .status)
    try c.encodeNullable(ageSeconds, forKey: .ageSeconds)
    try c.encode(stale, forKey: .stale)
    try c.encodeNullable(unavailableCause, forKey: .unavailableCause)
    try c.encode(unavailableCauseCodes, forKey: .unavailableCauseCodes)
    try c.encode(summary, forKey: .summary)
    try c.encode(pollSeconds, forKey: .pollSeconds)
    try c.encodeNullable(apiStartedAt, forKey: .apiStartedAt)
    if scheduleSent {
      try c.encodeNullable(schedule, forKey: .schedule)
      try c.encodeNullable(scheduleCause, forKey: .scheduleCause)
      try c.encode(scheduleCauseCodes, forKey: .scheduleCauseCodes)
    }
  }

  /// Why the bot's status is unavailable, in the person's language (the bot's words for an unknown code).
  public var unavailableCauseText: String? { ApiText.prose(unavailableCauseCodes, text: unavailableCause) }

  /// Why the schedule is unknown, in the person's language (the bot's words for an unknown code).
  public var scheduleCauseText: String? { ApiText.prose(scheduleCauseCodes, text: scheduleCause) }
}

/// When the bot is meant to run (GET /status `schedule`, from the bot's trading calendar): a run
/// is 04:00 ET to the day's extended close (20:00, 17:00 on an enabled half day). Times are UTC;
/// `timezone` is the calendar's (America/New_York).
public struct BotScheduleV1: Codable, Hashable, Sendable {
  public let timezone: String
  /// Whether a run is meant to be going at the API's `served_at`.
  public let expectedRunning: Bool
  /// When the run going now ends; nil unless `expectedRunning`.
  public let runEndsAt: WireTime?
  /// The next run after `served_at`: its start and end.
  public let nextStartAt: WireTime
  public let nextEndAt: WireTime
  /// The last trading day before or on `served_at`'s date.
  public let lastTradingDay: WireDate

  enum CodingKeys: String, CodingKey {
    case timezone
    case expectedRunning = "expected_running"
    case runEndsAt = "run_ends_at"
    case nextStartAt = "next_start_at"
    case nextEndAt = "next_end_at"
    case lastTradingDay = "last_trading_day"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    timezone = try c.decode(String.self, forKey: .timezone)
    expectedRunning = try c.decode(Bool.self, forKey: .expectedRunning)
    runEndsAt = try c.decodeNullable(WireTime.self, forKey: .runEndsAt)
    nextStartAt = try c.decode(WireTime.self, forKey: .nextStartAt)
    nextEndAt = try c.decode(WireTime.self, forKey: .nextEndAt)
    lastTradingDay = try c.decode(WireDate.self, forKey: .lastTradingDay)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(timezone, forKey: .timezone)
    try c.encode(expectedRunning, forKey: .expectedRunning)
    try c.encodeNullable(runEndsAt, forKey: .runEndsAt)
    try c.encode(nextStartAt, forKey: .nextStartAt)
    try c.encode(nextEndAt, forKey: .nextEndAt)
    try c.encode(lastTradingDay, forKey: .lastTradingDay)
  }
}
