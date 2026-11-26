import Foundation

// Swift mirror of the stop-bot mode and progress and of command-v1 in src/tickr/api/contract.py
// (backlog V4); their own file to keep Contract.swift within the file length limit.

/// What a stop-bot does with open positions (backlog V4); nil keeps the old rule (refused while any is open).
public enum StopMode: String, Codable, Sendable, CaseIterable {
  case closeAndStop = "close_and_stop"
  case leaveOpen = "leave_open"
}

/// Where an obeyed or running stop-bot is (`StatusV1.stopProgress`).
public enum StopStep: String, Codable, Sendable {
  case closingPositions = "closing_positions"
  case positionsClosed = "positions_closed"
  case stopping
  case stopped
}

/// A stop-bot the bot obeyed or is carrying out (added after version 1 shipped).
public struct StopProgress: Codable, Hashable, Sendable {
  public let commandId: String
  public let mode: StopMode?
  public let step: StopStep
  public let since: WireTime
  /// The bot's own trades not closed when the status was written.
  public let openTrades: Int

  enum CodingKeys: String, CodingKey {
    case mode, step, since
    case commandId = "command_id"
    case openTrades = "open_trades"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    commandId = try c.decode(String.self, forKey: .commandId)
    mode = try c.decodeNullable(StopMode.self, forKey: .mode)
    step = try c.decode(StopStep.self, forKey: .step)
    since = try c.decode(WireTime.self, forKey: .since)
    openTrades = try c.decode(Int.self, forKey: .openTrades)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(commandId, forKey: .commandId)
    try c.encodeNullable(mode, forKey: .mode)
    try c.encode(step, forKey: .step)
    try c.encode(since, forKey: .since)
    try c.encode(openTrades, forKey: .openTrades)
  }
}

public struct CommandV1: Codable, Hashable, Sendable {
  public let commandId: String
  public let kind: CommandKind
  public let requestedAt: WireTime
  public let source: String
  /// The one symbol a flatten closes; nil for every other command and for a flatten of everything.
  public let symbol: String?
  /// A stop-bot's mode (added after version 1 shipped); nil for every other command and a stop-bot without one.
  public let mode: StopMode?
  public let schemaVersion: Int

  enum CodingKeys: String, CodingKey {
    case kind, source, symbol, mode
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
    mode = try c.decodeIfPresent(StopMode.self, forKey: .mode)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(commandId, forKey: .commandId)
    try c.encode(kind, forKey: .kind)
    try c.encode(requestedAt, forKey: .requestedAt)
    try c.encode(source, forKey: .source)
    try c.encodeNullable(symbol, forKey: .symbol)
    try c.encodeNullable(mode, forKey: .mode)
    try c.encode(schemaVersion, forKey: .schemaVersion)
  }
}
