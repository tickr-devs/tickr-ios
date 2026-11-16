import Foundation

// Swift mirror of src/tickr/api/contract.py, version 1. JSON keys are spelled out in
// CodingKeys so a rename on either side fails the fixture tests instead of decoding silently.

public enum BotState: String, Codable, Sendable { case starting, running, stopping, stopped }

public enum StopState: String, Codable, Sendable { case verified, pending, missing, unknown }

public enum StreamHealth: String, Codable, Sendable { case fresh, quiet, lost, off }

public enum CommandKind: String, Codable, Sendable, CaseIterable {
  case entryStopOn = "entry-stop-on"
  case entryStopOff = "entry-stop-off"
  case cancelOwnOrders = "cancel-own-orders"
  case flatten
  case stopBot = "stop-bot"
  case emergency
}

public enum CommandOutcome: String, Codable, Sendable { case done, refused }

public struct StrategyId: Codable, Hashable, Sendable {
  public let name: String
  public let version: String
}

public struct EntryBlock: Codable, Hashable, Sendable {
  public let cause: String
  public let text: String
  /// False for an ordinary state that passes on its own (a position is already open, the time
  /// is outside the entry window): show it calmly, not as a warning.
  public let attention: Bool
  /// The values `text` names, by name (docs/api.md, "Reason codes"); empty when it names none.
  public let params: [String: String]

  enum CodingKeys: String, CodingKey {
    case cause
    case text
    case attention
    case params
  }

  public init(cause: String, text: String, attention: Bool, params: [String: String] = [:]) {
    self.cause = cause
    self.text = text
    self.attention = attention
    self.params = params
  }

  /// `attention` was added after version 1 shipped: a block written by an older bot has no
  /// such key and was always a warning.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    cause = try c.decode(String.self, forKey: .cause)
    text = try c.decode(String.self, forKey: .text)
    attention = try c.decodeIfPresent(Bool.self, forKey: .attention) ?? true
    // Added after version 1 shipped, like `attention`.
    params = try c.decodeIfPresent([String: String].self, forKey: .params) ?? [:]
  }
}

public struct Freshness: Codable, Hashable, Sendable {
  public let lastBrokerReadAt: WireTime?
  public let lastQuoteAt: WireTime?
  public let stream: StreamHealth

  enum CodingKeys: String, CodingKey {
    case stream
    case lastBrokerReadAt = "last_broker_read_at"
    case lastQuoteAt = "last_quote_at"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    lastBrokerReadAt = try c.decodeNullable(WireTime.self, forKey: .lastBrokerReadAt)
    lastQuoteAt = try c.decodeNullable(WireTime.self, forKey: .lastQuoteAt)
    stream = try c.decode(StreamHealth.self, forKey: .stream)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeNullable(lastBrokerReadAt, forKey: .lastBrokerReadAt)
    try c.encodeNullable(lastQuoteAt, forKey: .lastQuoteAt)
    try c.encode(stream, forKey: .stream)
  }
}

public struct CommandRecord: Codable, Hashable, Sendable {
  public let commandId: String
  public let kind: CommandKind
  public let requestedAt: WireTime
  public let processedAt: WireTime
  public let outcome: CommandOutcome
  public let cause: String?

  enum CodingKeys: String, CodingKey {
    case kind, outcome, cause
    case commandId = "command_id"
    case requestedAt = "requested_at"
    case processedAt = "processed_at"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    commandId = try c.decode(String.self, forKey: .commandId)
    kind = try c.decode(CommandKind.self, forKey: .kind)
    requestedAt = try c.decode(WireTime.self, forKey: .requestedAt)
    processedAt = try c.decode(WireTime.self, forKey: .processedAt)
    outcome = try c.decode(CommandOutcome.self, forKey: .outcome)
    cause = try c.decodeNullable(String.self, forKey: .cause)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(commandId, forKey: .commandId)
    try c.encode(kind, forKey: .kind)
    try c.encode(requestedAt, forKey: .requestedAt)
    try c.encode(processedAt, forKey: .processedAt)
    try c.encode(outcome, forKey: .outcome)
    try c.encodeNullable(cause, forKey: .cause)
  }
}

/// What the bot writes to its status file; served inside StatusResponseV1.
public struct StatusV1: Codable, Hashable, Sendable {
  public let writtenAt: WireTime
  public let botState: BotState
  public let runId: String?
  public let environment: String
  public let tradingGate: Gate
  public let strategy: StrategyId
  public let entryStop: Bool
  public let entryBlock: EntryBlock?
  public let fences: [Fence]
  public let position: Position?
  public let tradesToday: [Trade]
  public let resultTodayGrossUsd: DecimalString
  public let freshness: Freshness
  public let recentCommands: [CommandRecord]
  /// Realized loss counted against the daily limit; nil when the bot cannot compute it.
  public let realizedLossTodayUsd: DecimalString?
  /// Worst-case loss reserved by entries in flight; nil when unknown.
  public let openReservationsUsd: DecimalString?
  /// What is left of the daily loss limit after losses and reservations; nil when unknown.
  public let dailyRoomUsd: DecimalString?
  /// Every open position; `position` is the first of them, kept for older readers.
  public let positions: [Position]
  /// The code version the running bot's run records; nil when not recorded. See `CodeVersion`.
  public let codeVersion: String?
  public let schemaVersion: Int

  enum CodingKeys: String, CodingKey {
    case environment, strategy, fences, position, freshness, positions
    case codeVersion = "code_version"
    case writtenAt = "written_at"
    case botState = "bot_state"
    case runId = "run_id"
    case tradingGate = "trading_gate"
    case entryStop = "entry_stop"
    case entryBlock = "entry_block"
    case tradesToday = "trades_today"
    case resultTodayGrossUsd = "result_today_gross_usd"
    case recentCommands = "recent_commands"
    case realizedLossTodayUsd = "realized_loss_today_usd"
    case openReservationsUsd = "open_reservations_usd"
    case dailyRoomUsd = "daily_room_usd"
    case schemaVersion = "schema_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try c.decodeVersion(forKey: .schemaVersion, expected: Wire.statusSchemaVersion)
    writtenAt = try c.decode(WireTime.self, forKey: .writtenAt)
    botState = try c.decode(BotState.self, forKey: .botState)
    runId = try c.decodeNullable(String.self, forKey: .runId)
    environment = try c.decode(String.self, forKey: .environment)
    tradingGate = try c.decode(Gate.self, forKey: .tradingGate)
    strategy = try c.decode(StrategyId.self, forKey: .strategy)
    entryStop = try c.decode(Bool.self, forKey: .entryStop)
    entryBlock = try c.decodeNullable(EntryBlock.self, forKey: .entryBlock)
    fences = try c.decode([Fence].self, forKey: .fences)
    position = try c.decodeNullable(Position.self, forKey: .position)
    tradesToday = try c.decode([Trade].self, forKey: .tradesToday)
    resultTodayGrossUsd = try c.decode(DecimalString.self, forKey: .resultTodayGrossUsd)
    freshness = try c.decode(Freshness.self, forKey: .freshness)
    recentCommands = try c.decode([CommandRecord].self, forKey: .recentCommands)
    realizedLossTodayUsd = try c.decodeNullable(DecimalString.self, forKey: .realizedLossTodayUsd)
    openReservationsUsd = try c.decodeNullable(DecimalString.self, forKey: .openReservationsUsd)
    dailyRoomUsd = try c.decodeNullable(DecimalString.self, forKey: .dailyRoomUsd)
    positions = try c.decode([Position].self, forKey: .positions)
    // Added after version 1 shipped: an older bot's status has no such key.
    codeVersion = try c.decodeIfPresent(String.self, forKey: .codeVersion)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(schemaVersion, forKey: .schemaVersion)
    try c.encode(writtenAt, forKey: .writtenAt)
    try c.encode(botState, forKey: .botState)
    try c.encodeNullable(runId, forKey: .runId)
    try c.encode(environment, forKey: .environment)
    try c.encode(tradingGate, forKey: .tradingGate)
    try c.encode(strategy, forKey: .strategy)
    try c.encode(entryStop, forKey: .entryStop)
    try c.encodeNullable(entryBlock, forKey: .entryBlock)
    try c.encode(fences, forKey: .fences)
    try c.encodeNullable(position, forKey: .position)
    try c.encode(tradesToday, forKey: .tradesToday)
    try c.encode(resultTodayGrossUsd, forKey: .resultTodayGrossUsd)
    try c.encode(freshness, forKey: .freshness)
    try c.encode(recentCommands, forKey: .recentCommands)
    try c.encodeNullable(realizedLossTodayUsd, forKey: .realizedLossTodayUsd)
    try c.encodeNullable(openReservationsUsd, forKey: .openReservationsUsd)
    try c.encodeNullable(dailyRoomUsd, forKey: .dailyRoomUsd)
    try c.encode(positions, forKey: .positions)
    try c.encodeNullable(codeVersion, forKey: .codeVersion)
  }
}

public struct CommandV1: Codable, Hashable, Sendable {
  public let commandId: String
  public let kind: CommandKind
  public let requestedAt: WireTime
  public let source: String
  /// The one symbol a flatten closes; nil for every other command and for a flatten of everything.
  public let symbol: String?
  public let schemaVersion: Int

  enum CodingKeys: String, CodingKey {
    case kind, source, symbol
    case commandId = "command_id"
    case requestedAt = "requested_at"
    case schemaVersion = "schema_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try c.decodeVersion(forKey: .schemaVersion, expected: Wire.commandSchemaVersion)
    commandId = try c.decode(String.self, forKey: .commandId)
    kind = try c.decode(CommandKind.self, forKey: .kind)
    requestedAt = try c.decode(WireTime.self, forKey: .requestedAt)
    source = try c.decode(String.self, forKey: .source)
    symbol = try c.decodeNullable(String.self, forKey: .symbol)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(commandId, forKey: .commandId)
    try c.encode(kind, forKey: .kind)
    try c.encode(requestedAt, forKey: .requestedAt)
    try c.encode(source, forKey: .source)
    try c.encodeNullable(symbol, forKey: .symbol)
    try c.encode(schemaVersion, forKey: .schemaVersion)
  }
}

/// GET /status. Always this shape; `status` is nil when the bot's file is missing or bad.
public struct StatusResponseV1: Codable, Hashable, Sendable {
  public let servedAt: WireTime
  public let status: StatusV1?
  public let ageSeconds: DecimalString?
  public let stale: Bool
  public let unavailableCause: String?
  public let summary: String
  public let pollSeconds: DecimalString
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case status, stale, summary
    case servedAt = "served_at"
    case ageSeconds = "age_seconds"
    case unavailableCause = "unavailable_cause"
    case pollSeconds = "poll_seconds"
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    servedAt = try c.decode(WireTime.self, forKey: .servedAt)
    status = try c.decodeNullable(StatusV1.self, forKey: .status)
    ageSeconds = try c.decodeNullable(DecimalString.self, forKey: .ageSeconds)
    stale = try c.decode(Bool.self, forKey: .stale)
    unavailableCause = try c.decodeNullable(String.self, forKey: .unavailableCause)
    summary = try c.decode(String.self, forKey: .summary)
    pollSeconds = try c.decode(DecimalString.self, forKey: .pollSeconds)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(servedAt, forKey: .servedAt)
    try c.encodeNullable(status, forKey: .status)
    try c.encodeNullable(ageSeconds, forKey: .ageSeconds)
    try c.encode(stale, forKey: .stale)
    try c.encodeNullable(unavailableCause, forKey: .unavailableCause)
    try c.encode(summary, forKey: .summary)
    try c.encode(pollSeconds, forKey: .pollSeconds)
  }
}

/// POST /pair on the remote port: the bearer token a pairing code bought, answered once.
public struct PairedV1: Codable, Hashable, Sendable {
  public let token: String
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case token
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    token = try c.decode(String.self, forKey: .token)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(token, forKey: .token)
  }
}

/// POST /commands/*: queued for the bot, not yet executed.
public struct CommandAcceptedV1: Codable, Hashable, Sendable {
  public let command: CommandV1
  public let warning: String?
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case command, warning
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    command = try c.decode(CommandV1.self, forKey: .command)
    warning = try c.decodeNullable(String.self, forKey: .warning)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(apiVersion, forKey: .apiVersion)
    try c.encode(command, forKey: .command)
    try c.encodeNullable(warning, forKey: .warning)
  }
}

/// GET /commands/pending.
public struct PendingCommandsV1: Codable, Hashable, Sendable {
  public let commands: [CommandV1]
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case commands
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    commands = try c.decode([CommandV1].self, forKey: .commands)
  }
}

/// Every non-2xx answer.
public struct ErrorV1: Codable, Hashable, Sendable {
  public let error: String
  public let cause: String
  public let apiVersion: Int

  enum CodingKeys: String, CodingKey {
    case error, cause
    case apiVersion = "api_version"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    apiVersion = try c.decodeVersion(forKey: .apiVersion, expected: Wire.apiVersion)
    error = try c.decode(String.self, forKey: .error)
    cause = try c.decode(String.self, forKey: .cause)
  }
}
