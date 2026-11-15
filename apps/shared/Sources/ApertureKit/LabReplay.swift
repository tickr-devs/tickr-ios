import Foundation

// Swift mirror of lab-replay-v1 (GET and POST /lab/replay) in src/aperture/api/contract.py: the
// Lab's replay of the current strategy over the recent recorded sessions, and its summary.

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
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case state, strategy, version, sessions, cause, summary
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
    try c.encode(apiVersion, forKey: .apiVersion)
  }
}
