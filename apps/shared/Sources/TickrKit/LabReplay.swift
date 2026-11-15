import Foundation

// Swift mirror of lab-replay-v1 (GET and POST /lab/replay) in src/tickr/api/contract.py: the
// Lab's replay of a strategy version over the recent recorded sessions or one day, optionally
// compared with a second version, and what a run may ask for.

/// Where the replay is: never run, running, finished with a summary, or failed with a cause.
public enum LabReplayState: String, Codable, Sendable, CaseIterable {
  case idle, running, done, failed
}

/// What a finished replay found: the days it covered, the replayed trades in R with their
/// confidence interval, and the bot's own trades over the same days in USD.
public struct LabReplaySummaryV1: Codable, Hashable, Sendable {
  public let firstDay: WireDate
  public let lastDay: WireDate
  public let sessions: Int
  public let sessionsWithoutReplayedDays: Int
  public let replayedSymbolDays: Int
  public let trades: Int
  public let winRatePercent: DecimalString?
  public let meanR: DecimalString?
  public let totalR: DecimalString?
  public let profitFactor: DecimalString?
  public let meanRIntervalLow: DecimalString?
  public let meanRIntervalHigh: DecimalString?
  public let confidencePercent: DecimalString
  public let maxDrawdownR: DecimalString?
  public let botTrades: Int
  public let botTotalUsd: DecimalString
  public let botMaxDrawdownUsd: DecimalString?

  enum CodingKeys: String, CodingKey {
    case sessions, trades
    case firstDay = "first_day"
    case lastDay = "last_day"
    case sessionsWithoutReplayedDays = "sessions_without_replayed_days"
    case replayedSymbolDays = "replayed_symbol_days"
    case winRatePercent = "win_rate_percent"
    case meanR = "mean_r"
    case totalR = "total_r"
    case profitFactor = "profit_factor"
    case meanRIntervalLow = "mean_r_interval_low"
    case meanRIntervalHigh = "mean_r_interval_high"
    case confidencePercent = "confidence_percent"
    case maxDrawdownR = "max_drawdown_r"
    case botTrades = "bot_trades"
    case botTotalUsd = "bot_total_usd"
    case botMaxDrawdownUsd = "bot_max_drawdown_usd"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    firstDay = try c.decode(WireDate.self, forKey: .firstDay)
    lastDay = try c.decode(WireDate.self, forKey: .lastDay)
    sessions = try c.decode(Int.self, forKey: .sessions)
    sessionsWithoutReplayedDays = try c.decode(Int.self, forKey: .sessionsWithoutReplayedDays)
    replayedSymbolDays = try c.decode(Int.self, forKey: .replayedSymbolDays)
    trades = try c.decode(Int.self, forKey: .trades)
    winRatePercent = try c.decodeNullable(DecimalString.self, forKey: .winRatePercent)
    meanR = try c.decodeNullable(DecimalString.self, forKey: .meanR)
    totalR = try c.decodeNullable(DecimalString.self, forKey: .totalR)
    profitFactor = try c.decodeNullable(DecimalString.self, forKey: .profitFactor)
    meanRIntervalLow = try c.decodeNullable(DecimalString.self, forKey: .meanRIntervalLow)
    meanRIntervalHigh = try c.decodeNullable(DecimalString.self, forKey: .meanRIntervalHigh)
    confidencePercent = try c.decode(DecimalString.self, forKey: .confidencePercent)
    maxDrawdownR = try c.decodeNullable(DecimalString.self, forKey: .maxDrawdownR)
    botTrades = try c.decode(Int.self, forKey: .botTrades)
    botTotalUsd = try c.decode(DecimalString.self, forKey: .botTotalUsd)
    botMaxDrawdownUsd = try c.decodeNullable(DecimalString.self, forKey: .botMaxDrawdownUsd)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(firstDay, forKey: .firstDay)
    try c.encode(lastDay, forKey: .lastDay)
    try c.encode(sessions, forKey: .sessions)
    try c.encode(sessionsWithoutReplayedDays, forKey: .sessionsWithoutReplayedDays)
    try c.encode(replayedSymbolDays, forKey: .replayedSymbolDays)
    try c.encode(trades, forKey: .trades)
    try c.encodeNullable(winRatePercent, forKey: .winRatePercent)
    try c.encodeNullable(meanR, forKey: .meanR)
    try c.encodeNullable(totalR, forKey: .totalR)
    try c.encodeNullable(profitFactor, forKey: .profitFactor)
    try c.encodeNullable(meanRIntervalLow, forKey: .meanRIntervalLow)
    try c.encodeNullable(meanRIntervalHigh, forKey: .meanRIntervalHigh)
    try c.encode(confidencePercent, forKey: .confidencePercent)
    try c.encodeNullable(maxDrawdownR, forKey: .maxDrawdownR)
    try c.encode(botTrades, forKey: .botTrades)
    try c.encode(botTotalUsd, forKey: .botTotalUsd)
    try c.encodeNullable(botMaxDrawdownUsd, forKey: .botMaxDrawdownUsd)
  }
}

/// A strategy folder's place: the version that trades, a live observer, or any other folder.
public enum LabVersionRole: String, Codable, Sendable, CaseIterable {
  case active, observer, candidate
}

/// A strategy folder the Lab may replay; `cause` says why it cannot be (null when it can).
public struct LabVersionV1: Codable, Hashable, Sendable {
  public let folder: String
  public let strategy: String?
  public let version: String?
  public let role: LabVersionRole
  public let cause: String?

  enum CodingKeys: String, CodingKey {
    case folder, strategy, version, role, cause
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    folder = try c.decode(String.self, forKey: .folder)
    strategy = try c.decodeNullable(String.self, forKey: .strategy)
    version = try c.decodeNullable(String.self, forKey: .version)
    role = try c.decode(LabVersionRole.self, forKey: .role)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(folder, forKey: .folder)
    try c.encodeNullable(strategy, forKey: .strategy)
    try c.encodeNullable(version, forKey: .version)
    try c.encode(role, forKey: .role)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// The second version of a comparison, replayed after the first over the same window.
public struct LabReplayLegV1: Codable, Hashable, Sendable {
  public let folder: String
  public let strategy: String
  public let version: String
  public let state: LabReplayState
  public let cause: String?
  public let summary: LabReplaySummaryV1?

  enum CodingKeys: String, CodingKey {
    case folder, strategy, version, state, cause, summary
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    folder = try c.decode(String.self, forKey: .folder)
    strategy = try c.decode(String.self, forKey: .strategy)
    version = try c.decode(String.self, forKey: .version)
    state = try c.decode(LabReplayState.self, forKey: .state)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    summary = try c.decodeNullable(LabReplaySummaryV1.self, forKey: .summary)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(folder, forKey: .folder)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(version, forKey: .version)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encodeNullable(summary, forKey: .summary)
  }
}

/// GET /lab/replay, and the answer to POST /lab/replay (202).
public struct LabReplayV1: Codable, Hashable, Sendable {
  public let state: LabReplayState
  public let runId: String?
  public let strategy: String?
  public let version: String?
  /// How many recent sessions the replay covers.
  public let sessions: Int
  public let startedAt: WireTime?
  public let finishedAt: WireTime?
  /// Why the replay failed or has nothing to show.
  public let cause: String?
  /// Set once the replay is done.
  public let summary: LabReplaySummaryV1?
  /// The strategy folder replayed first; nil for a run of an older API.
  public let folder: String?
  /// The one day replayed; nil when the run covers the last sessions.
  public let day: WireDate?
  /// The second version of a comparison.
  public let compare: LabReplayLegV1?
  /// Every folder a run may name, the active one first.
  public let versions: [LabVersionV1]
  /// Days "replay one day" offers, newest first.
  public let days: [WireDate]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case state, strategy, version, sessions, cause, summary, folder, day, compare, versions, days
    case runId = "run_id"
    case startedAt = "started_at"
    case finishedAt = "finished_at"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    state = try c.decode(LabReplayState.self, forKey: .state)
    runId = try c.decodeNullable(String.self, forKey: .runId)
    strategy = try c.decodeNullable(String.self, forKey: .strategy)
    version = try c.decodeNullable(String.self, forKey: .version)
    sessions = try c.decode(Int.self, forKey: .sessions)
    startedAt = try c.decodeNullable(WireTime.self, forKey: .startedAt)
    finishedAt = try c.decodeNullable(WireTime.self, forKey: .finishedAt)
    cause = try c.decodeNullable(String.self, forKey: .cause)
    summary = try c.decodeNullable(LabReplaySummaryV1.self, forKey: .summary)
    // Added after version 1 shipped: an older API writes none of them.
    folder = try c.decodeIfPresent(String.self, forKey: .folder)
    day = try c.decodeIfPresent(WireDate.self, forKey: .day)
    compare = try c.decodeIfPresent(LabReplayLegV1.self, forKey: .compare)
    versions = try c.decodeIfPresent([LabVersionV1].self, forKey: .versions) ?? []
    days = try c.decodeIfPresent([WireDate].self, forKey: .days) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(state, forKey: .state)
    try c.encodeNullable(runId, forKey: .runId)
    try c.encodeNullable(strategy, forKey: .strategy)
    try c.encodeNullable(version, forKey: .version)
    try c.encode(sessions, forKey: .sessions)
    try c.encodeNullable(startedAt, forKey: .startedAt)
    try c.encodeNullable(finishedAt, forKey: .finishedAt)
    try c.encodeNullable(cause, forKey: .cause)
    try c.encodeNullable(summary, forKey: .summary)
    try c.encodeNullable(folder, forKey: .folder)
    try c.encodeNullable(day, forKey: .day)
    try c.encodeNullable(compare, forKey: .compare)
    try c.encode(versions, forKey: .versions)
    try c.encode(days, forKey: .days)
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
