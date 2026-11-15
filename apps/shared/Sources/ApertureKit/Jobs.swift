import Foundation

// Swift mirror of jobs-v1 (GET /jobs) in src/aperture/api/contract.py: what runs on its own on the
// Mac (the bot's reconcile loop, the database backup, the launchd jobs) and today's session times.

/// The bot's reconcile loop: how often it runs, when it last ran and, while the bot runs, next.
public struct ReconcileJobV1: Codable, Hashable, Sendable {
  public let intervalSeconds: DecimalString
  public let lastAt: WireTime?
  /// Set only while the bot runs.
  public let nextAt: WireTime?

  enum CodingKeys: String, CodingKey {
    case intervalSeconds = "interval_seconds"
    case lastAt = "last_at"
    case nextAt = "next_at"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    intervalSeconds = try c.decode(DecimalString.self, forKey: .intervalSeconds)
    lastAt = try c.decodeNullable(WireTime.self, forKey: .lastAt)
    nextAt = try c.decodeNullable(WireTime.self, forKey: .nextAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(intervalSeconds, forKey: .intervalSeconds)
    try c.encodeNullable(lastAt, forKey: .lastAt)
    try c.encodeNullable(nextAt, forKey: .nextAt)
  }
}

/// The database backup: the last good one, the last failure with its error, or why neither is known.
public struct BackupJobV1: Codable, Hashable, Sendable {
  public let lastAt: WireTime?
  public let lastFailedAt: WireTime?
  public let lastFailedError: String?
  public let cause: String?

  enum CodingKeys: String, CodingKey {
    case cause
    case lastAt = "last_at"
    case lastFailedAt = "last_failed_at"
    case lastFailedError = "last_failed_error"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    lastAt = try c.decodeNullable(WireTime.self, forKey: .lastAt)
    lastFailedAt = try c.decodeNullable(WireTime.self, forKey: .lastFailedAt)
    lastFailedError = try c.decodeNullable(String.self, forKey: .lastFailedError)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(lastAt, forKey: .lastAt)
    try c.encodeNullable(lastFailedAt, forKey: .lastFailedAt)
    try c.encodeNullable(lastFailedError, forKey: .lastFailedError)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// A launchd job on the Mac: its name, its start time in the Mac's local time ("HH:MM") and the
/// weekdays it runs on, in launchd numbering as in the Python contract: 1 = Monday … 5 = Friday,
/// and both 0 and 7 mean Sunday.
public struct LaunchdJobV1: Codable, Hashable, Sendable {
  public let name: String
  public let localTime: String
  public let weekdays: [Int]

  enum CodingKeys: String, CodingKey {
    case name, weekdays
    case localTime = "local_time"
  }
}

/// Today's regular session in New York, from the exchange calendar.
public struct SessionTimesV1: Codable, Hashable, Sendable {
  public let day: WireDate
  public let regularOpen: WireTime
  public let lastEntryAt: WireTime
  public let flattenAt: WireTime
  public let regularClose: WireTime

  enum CodingKeys: String, CodingKey {
    case day
    case regularOpen = "regular_open"
    case lastEntryAt = "last_entry_at"
    case flattenAt = "flatten_at"
    case regularClose = "regular_close"
  }
}

/// GET /jobs.
public struct JobsV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let botState: BotState?
  public let statusStale: Bool
  public let botStartedAt: WireTime?
  public let reconcile: ReconcileJobV1
  public let backup: BackupJobV1
  public let launchd: [LaunchdJobV1]
  /// Nil with `sessionCause` on a day with no session (a weekend, a holiday).
  public let session: SessionTimesV1?
  public let sessionCause: String?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case reconcile, backup, launchd, session
    case servedAt = "served_at"
    case botState = "bot_state"
    case statusStale = "status_stale"
    case botStartedAt = "bot_started_at"
    case sessionCause = "session_cause"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    botState = try c.decodeNullable(BotState.self, forKey: .botState)
    statusStale = try c.decode(Bool.self, forKey: .statusStale)
    botStartedAt = try c.decodeNullable(WireTime.self, forKey: .botStartedAt)
    reconcile = try c.decode(ReconcileJobV1.self, forKey: .reconcile)
    backup = try c.decode(BackupJobV1.self, forKey: .backup)
    launchd = try c.decode([LaunchdJobV1].self, forKey: .launchd)
    session = try c.decodeNullable(SessionTimesV1.self, forKey: .session)
    sessionCause = try c.decodeNullable(String.self, forKey: .sessionCause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(servedAt, forKey: .servedAt)
    try c.encodeNullable(botState, forKey: .botState)
    try c.encode(statusStale, forKey: .statusStale)
    try c.encodeNullable(botStartedAt, forKey: .botStartedAt)
    try c.encode(reconcile, forKey: .reconcile)
    try c.encode(backup, forKey: .backup)
    try c.encode(launchd, forKey: .launchd)
    try c.encodeNullable(session, forKey: .session)
    try c.encodeNullable(sessionCause, forKey: .sessionCause)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
