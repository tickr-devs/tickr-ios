import Foundation

/// Presentation facts derived from a status document, shared by the apps. Pure, so tests pin them.
public enum Board {
  /// Closed trades of the day split into wins and losses, plus the day's result: after the
  /// broker's fees once the bot reports them, else before them (`beforeFees`; a recorded day is gross).
  public struct DayStats: Equatable, Sendable {
    public let trades: Int
    public let wins: Int
    public let losses: Int
    public let resultUsd: Decimal
    /// The result does not count the broker's fees yet: a recorded day (its summary is gross),
    /// or today before the bot has read every fill's fees. False without trades.
    public let beforeFees: Bool

    /// Wins as a share of closed trades, 0 when there were none.
    public var winShare: Double { trades == 0 ? 0 : Double(wins) / Double(trades) }
  }

  public static func dayStats(_ status: StatusV1) -> DayStats {
    let results = status.tradesToday.map(\.resultUsd.value)
    return DayStats(
      trades: results.count,
      wins: results.filter { $0 > 0 }.count,
      losses: results.filter { $0 < 0 }.count,
      resultUsd: status.resultTodayUsd.value, beforeFees: status.resultBeforeFees)
  }

  /// A recorded day's numbers, as GET /days summarizes it.
  public static func dayStats(_ day: DaySummary) -> DayStats {
    DayStats(
      trades: day.trades, wins: day.wins, losses: day.losses, resultUsd: day.resultGrossUsd.value,
      beforeFees: day.trades > 0)
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
  static let refusalID = "refusal-"
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
        text: String(localized: L10n.eventQuantityAt(trade.symbol, trade.quantity.text, trade.entryPrice.text)),
        tone: .teal))
      let result = trade.resultUsd.value
      events.append(Event(
        id: "\(tradeID)\(index)\(exitID)", time: trade.closedAt.date, tag: exitReasonTitle(trade.exitReason).uppercased(),
        text: String(localized: L10n.eventExitAt(trade.symbol, trade.exitPrice.text, signed(trade.resultUsd))),
        tone: exitTone(trade.exitReason, result: result)))
    }
    for position in status.positions {
      events.append(Event(
        id: "\(positionID)\(position.symbol)\(openID)", time: position.openedAt.date,
        tag: String(localized: L10n.tagOpen),
        text: String(localized: L10n.eventQuantityAt(position.symbol, position.quantity.text, position.entryPrice.text)),
        tone: .teal))
      events.append(Event(
        id: "\(positionID)\(position.symbol)\(stopID)", time: position.openedAt.date,
        tag: stopTag(position.stop.state),
        text: "\(position.symbol) \(position.stop.price?.text ?? String(localized: L10n.noPrice))",
        tone: position.stop.state.isProtected ? .green : .red))
    }
    for fence in status.fences {
      events.append(Event(
        id: "\(fenceID)\(fence.kind)", time: fence.since.date, tag: String(localized: L10n.tagFence),
        text: fenceText(fence, status: status), tone: .amber))
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

  /// Joins the parts of a client order id ("<prefix><run>-<trade>-<leg><n>",
  /// src/tickr/engine/core.py `_client_order_id`), so a fence keyed by a trade id finds the
  /// position whose order carries it.
  static let orderIDSeparator = "-"

  /// The symbol a fence is about: the open position, or else today's closed trade, whose entry
  /// or stop order id is the fence's key or carries it as its trade id. A fence raised while a
  /// position was unprotected still names it after the exit. Nil when nothing matches (never
  /// guessed).
  public static func fenceSymbol(_ fence: Fence, status: StatusV1) -> String? {
    let parts = fence.kind.split(separator: Fence.keySeparator, maxSplits: 1)
    guard parts.count > 1 else { return nil }
    let key = String(parts[1])
    let trade = orderIDSeparator + key + orderIDSeparator
    func matches(_ ids: [String?]) -> Bool {
      let ids = ids.compactMap { $0 }
      return ids.contains(key) || ids.contains { $0.contains(trade) }
    }
    if let open = status.positions.first(where: { matches([$0.entry.clientOrderId, $0.stop.clientOrderId]) }) {
      return open.symbol
    }
    return status.tradesToday.first { matches([$0.entry.clientOrderId]) }?.symbol
  }

  /// A fence's title for a person: the symbol it is about in place of the bot's key, when known.
  public static func fenceTitle(_ fence: Fence, status: StatusV1) -> String {
    ApiText.fence(fence, symbol: fenceSymbol(fence, status: status))
  }

  /// A fence in words for the event line and the flow card: the symbol it is about first when
  /// known, then what it is and what it says.
  public static func fenceText(_ fence: Fence, status: StatusV1) -> String {
    ApiText.fenceWithDetail(fence, symbol: fenceSymbol(fence, status: status))
  }

  /// Between a refused symbol and why it was refused.
  public static let refusalGap = " "

  /// The newest thing that happened today, for the event line: the first of `events(status)` or
  /// the latest risk refusal in `skipped`, whichever came later. The status does not list
  /// refusals, but a refused entry is an event too.
  public static func latestEvent(_ status: StatusV1, skipped: SkippedV1?) -> Event? {
    let event = events(status).first
    let refusal = skipped?.signals.filter { $0.admission == .refused }.max { $0.at.date < $1.at.date }.map {
      Event(id: "\(refusalID)\($0.symbol)", time: $0.at.date, tag: String(localized: L10n.tagRefused),
        text: [$0.symbol, FlowBoard.note($0)].compactMap { $0 }.joined(separator: refusalGap), tone: .amber)
    }
    guard let event, let refusal else { return event ?? refusal }
    return refusal.time > event.time ? refusal : event
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

  /// How an exit reads apart from its result: an ordinary exit (a stop hit, the strategy's own
  /// exit, the operator closing one trade, a hold that ran out), a forced close the bot or the
  /// operator made to stay safe, or a failure to keep the position protected.
  public enum ExitKind: Sendable, Equatable {
    case ordinary
    case forced
    case protectionFailure
  }

  /// The kind of an exit reason; a reason this app does not know is treated as forced, so it is
  /// never shown as an ordinary win.
  public static func exitKind(_ raw: String) -> ExitKind {
    guard let reason = ExitReason(rawValue: raw) else { return .forced }
    switch reason {
    case .stopRejected, .unprotectedTooLong: return .protectionFailure
    case .streamLost, .sessionFlatten, .operatorFlatten, .operatorInterrupt: return .forced
    case .stoppedOut, .strategyExit, .operatorExit, .entryNotFilled, .entryNotFilledInTime, .holdElapsed, .closed:
      return .ordinary
    }
  }

  /// How a closed trade's reason tag reads (mockup v99, MacTrades and IOSActivity): the
  /// strategy's own exit, a stop hit, a failure to keep the position protected, or any other close
  /// (end of day, a plain close, the operator, a lost stream, an entry that never filled, a hold
  /// that ran out, a reason this app does not know). TickrDesign maps it to the tag's tone.
  public enum ExitLook: Sendable, Equatable, CaseIterable {
    case strategy
    case stoppedOut
    case protectionFailure
    case other
  }

  public static func exitLook(_ raw: String) -> ExitLook {
    switch ExitReason(rawValue: raw) {
    case .strategyExit: .strategy
    case .stoppedOut: .stoppedOut
    case .stopRejected, .unprotectedTooLong: .protectionFailure
    default: .other
    }
  }

  /// An exit event's tone: amber for a forced close and red for a protection failure whatever the
  /// result; an ordinary exit by its result's sign.
  public static func exitTone(_ raw: String, result: Decimal) -> Event.Tone {
    switch exitKind(raw) {
    case .protectionFailure: .red
    case .forced: .amber
    case .ordinary: result > 0 ? .green : result < 0 ? .red : .muted
    }
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
