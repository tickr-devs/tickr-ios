import Foundation

/// Presentation facts derived from a status document, shared by the apps. Pure, so tests pin them.
public enum Board {
  /// Closed trades of the day split into wins and losses, plus the day's gross result.
  public struct DayStats: Equatable, Sendable {
    public let trades: Int
    public let wins: Int
    public let losses: Int
    public let resultGrossUsd: Decimal

    /// Wins as a share of closed trades, 0 when there were none.
    public var winShare: Double { trades == 0 ? 0 : Double(wins) / Double(trades) }
  }

  public static func dayStats(_ status: StatusV1) -> DayStats {
    let results = status.tradesToday.map(\.resultGrossUsd.value)
    return DayStats(
      trades: results.count,
      wins: results.filter { $0 > 0 }.count,
      losses: results.filter { $0 < 0 }.count,
      resultGrossUsd: status.resultTodayGrossUsd.value)
  }

  /// A recorded day's numbers, as GET /days summarizes it.
  public static func dayStats(_ day: DaySummary) -> DayStats {
    DayStats(trades: day.trades, wins: day.wins, losses: day.losses, resultGrossUsd: day.resultGrossUsd.value)
  }

  /// Every open position, in the order the bot lists them.
  public static func positions(_ status: StatusV1) -> [Position] {
    status.positions
  }

  /// One thing that happened, for the event ticker and the journal.
  public struct Event: Identifiable, Equatable, Sendable {
    public enum Tone: Equatable, Sendable { case teal, green, blue, amber, violet, red, muted }

    public let id: String
    public let time: Date
    public let tag: String
    public let text: String
    public let tone: Tone
  }

  /// Event id parts: `trade-<index>-enter`, `trade-<index>-exit`, `position-<symbol>-open`,
  /// `position-<symbol>-stop`, `fence-<kind>` and `command-<id>`. Ids only sort and identify rows.
  static let tradeID = "trade-"
  static let positionID = "position-"
  static let fenceID = "fence-"
  static let commandID = "command-"
  static let enterID = "-enter"
  static let exitID = "-exit"
  static let openID = "-open"
  static let stopID = "-stop"

  /// Everything the status document says happened today, newest first: entries and exits of
  /// closed trades, the open position and its stop, fences, and operator command results.
  /// Status v1 has no time for the stop itself, so the position's stop event carries the
  /// position's `openedAt`.
  public static func events(_ status: StatusV1) -> [Event] {
    var events: [Event] = []
    for (index, trade) in status.tradesToday.enumerated() {
      events.append(Event(
        id: "\(tradeID)\(index)\(enterID)", time: trade.openedAt.date, tag: String(localized: L10n.tagEnter),
        text: "\(trade.symbol) \(trade.quantity) @ \(trade.entryPrice)", tone: .teal))
      let result = trade.resultGrossUsd.value
      events.append(Event(
        id: "\(tradeID)\(index)\(exitID)", time: trade.closedAt.date, tag: exitReasonTitle(trade.exitReason).uppercased(),
        text: "\(trade.symbol) @ \(trade.exitPrice) \(signed(trade.resultGrossUsd))",
        tone: result > 0 ? .green : result < 0 ? .red : .muted))
    }
    for position in status.positions {
      events.append(Event(
        id: "\(positionID)\(position.symbol)\(openID)", time: position.openedAt.date,
        tag: String(localized: L10n.tagOpen),
        text: "\(position.symbol) \(position.quantity) @ \(position.entryPrice)", tone: .teal))
      events.append(Event(
        id: "\(positionID)\(position.symbol)\(stopID)", time: position.openedAt.date,
        tag: stopTag(position.stop.state),
        text: "\(position.symbol) \(position.stop.price?.text ?? String(localized: L10n.noPrice))",
        tone: position.stop.state == .verified ? .green : .red))
    }
    for fence in status.fences {
      events.append(Event(
        id: "\(fenceID)\(fence.kind)", time: fence.since.date, tag: String(localized: L10n.tagFence),
        text: ApiText.fenceWithDetail(fence), tone: .amber))
    }
    for record in status.recentCommands {
      events.append(Event(
        id: "\(commandID)\(record.commandId)", time: record.processedAt.date,
        tag: String(localized: record.outcome == .done ? L10n.tagDone : L10n.tagRefused),
        text: commandTitle(record.kind) + (record.cause.map { ": \($0)" } ?? ""),
        tone: record.outcome == .done ? .blue : .red))
    }
    return events.sorted { $0.time == $1.time ? $0.id > $1.id : $0.time > $1.time }
  }

  public static func stopTag(_ state: StopState) -> String {
    switch state {
    case .verified: return String(localized: L10n.stopVerified)
    case .pending: return String(localized: L10n.stopPending)
    case .missing: return String(localized: L10n.stopMissing)
    case .unknown: return String(localized: L10n.stopUnknown)
    }
  }

  /// A stop state in a sentence ("missing", "pending"), in the person's language.
  public static func stopStateTitle(_ state: StopState) -> String {
    switch state {
    case .verified: return String(localized: L10n.stateVerified)
    case .pending: return String(localized: L10n.statePending)
    case .missing: return String(localized: L10n.stateMissing)
    case .unknown: return String(localized: L10n.stateUnknown)
    }
  }

  /// Why a trade closed (`exit_reason`, a protocol value), in the person's language. A reason this
  /// app does not know is shown as it arrived, never guessed.
  public static func exitReasonTitle(_ raw: String) -> String {
    guard let reason = ExitReason(rawValue: raw) else { return raw }
    return String(localized: reason.title)
  }

  /// The SF Symbol of an exit reason, for its pill; a reason this app does not know gets a question mark.
  public static func exitReasonSymbol(_ raw: String) -> String {
    ExitReason(rawValue: raw)?.symbol ?? ExitReason.unknownSymbol
  }

  public static func commandTitle(_ kind: CommandKind) -> String {
    switch kind {
    case .entryStopOn: return String(localized: L10n.commandPauseEntries)
    case .entryStopOff: return String(localized: L10n.commandResumeEntries)
    case .cancelOwnOrders: return String(localized: L10n.commandCancelOwnOrders)
    case .flatten: return String(localized: L10n.commandFlatten)
    case .stopBot: return String(localized: L10n.commandStopBot)
    case .emergency: return String(localized: L10n.commandEmergency)
    }
  }

  static func signed(_ value: DecimalString) -> String {
    value.isNegative ? value.text : "+" + value.text
  }
}

/// The exit reasons the bot records for a closed trade (`trades.close_cause` in the bot's store).
enum ExitReason: String {
  case stoppedOut = "stopped-out"
  case strategyExit = "strategy-exit"
  case operatorExit = "operator-exit"
  case operatorFlatten = "operator-flatten"
  case operatorInterrupt = "operator-interrupt"
  case sessionFlatten = "session-flatten"
  case streamLost = "stream-lost"
  case stopRejected = "stop-rejected"
  case unprotectedTooLong = "unprotected-too-long"
  case entryNotFilled = "entry-not-filled"
  case entryNotFilledInTime = "entry-not-filled-in-time"
  case holdElapsed = "hold-elapsed"
  case closed

  /// SF Symbols of the reasons: a reason this app does not know, a stop hit, the strategy's own
  /// exit, the operator, an interruption, the session's end, a lost stream, a protection failure,
  /// an entry that never filled, a hold that ran out, and a plain close.
  static let unknownSymbol = "questionmark.circle"
  static let stoppedOutSymbol = "xmark.shield"
  static let strategySymbol = "arrow.right.to.line"
  static let operatorSymbol = "hand.raised"
  static let interruptSymbol = "bolt.horizontal"
  static let sessionEndSymbol = "clock.badge.xmark"
  static let streamSymbol = "waveform.path.ecg"
  static let protectionSymbol = "exclamationmark.shield"
  static let notFilledSymbol = "hourglass"
  static let holdSymbol = "timer"
  static let closedSymbol = "checkmark.circle"

  var symbol: String {
    switch self {
    case .stoppedOut: return Self.stoppedOutSymbol
    case .strategyExit: return Self.strategySymbol
    case .operatorExit, .operatorFlatten: return Self.operatorSymbol
    case .operatorInterrupt: return Self.interruptSymbol
    case .sessionFlatten: return Self.sessionEndSymbol
    case .streamLost: return Self.streamSymbol
    case .stopRejected, .unprotectedTooLong: return Self.protectionSymbol
    case .entryNotFilled, .entryNotFilledInTime: return Self.notFilledSymbol
    case .holdElapsed: return Self.holdSymbol
    case .closed: return Self.closedSymbol
    }
  }

  var title: LocalizedStringResource {
    switch self {
    case .stoppedOut: return L10n.exitStoppedOut
    case .strategyExit: return L10n.exitStrategy
    case .operatorExit: return L10n.exitOperator
    case .operatorFlatten: return L10n.exitOperatorFlatten
    case .operatorInterrupt: return L10n.exitInterrupted
    case .sessionFlatten: return L10n.exitSessionEnd
    case .streamLost: return L10n.exitStreamLost
    case .stopRejected: return L10n.exitStopRejected
    case .unprotectedTooLong: return L10n.exitUnprotected
    case .entryNotFilled, .entryNotFilledInTime: return L10n.exitEntryNotFilled
    case .holdElapsed: return L10n.exitHoldElapsed
    case .closed: return L10n.exitClosed
    }
  }
}
