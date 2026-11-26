import Foundation

// What both apps show of a stop-bot with open positions (backlog V4 variant A; boards Main,
// MainNarrow, IOSHome): the question Stop bot asks, the steps of a close-and-stop, and the panel
// of a bot stopped with positions left open. Pure logic over the status; the views draw it.

/// What Stop bot asks before it sends anything.
public enum StopQuestion: Equatable, Sendable {
  /// Nothing open: the plain confirmation, and the stop goes without a mode.
  case confirm
  /// Positions open (their symbols, in the status's order): Close and stop, Leave open, or Cancel.
  case choose(symbols: [String])

  /// The question for the bot's open positions as the latest status lists them.
  public static func asked(positions: [Position]) -> StopQuestion {
    positions.isEmpty ? .confirm : .choose(symbols: positions.map(\.symbol))
  }
}

/// One line of the close-and-stop steps: the step, where it stands and when it began, if known.
public struct StopStepRow: Equatable, Sendable, Identifiable {
  public enum Phase: Equatable, Sendable {
    /// Over, or reached and nothing more to wait for (positions closed, bot stopped): green.
    case done
    /// Under way (closing positions, stopping): amber, pulsing on each status read.
    case running
    /// Not reached yet: grey, no time.
    case waiting
  }

  public let step: StopStep
  public let phase: Phase
  /// When the step began, as the bot reported it; nil when no status this app read said so
  /// (never a guess).
  public let since: Date?

  public var id: StopStep { step }

  /// The step's name.
  public var title: LocalizedStringResource {
    switch step {
    case .closingPositions: StopText.closingPositions
    case .positionsClosed: StopText.positionsClosed
    case .stopping: StopText.stopping
    case .stopped: StopText.stopped
    }
  }
}

/// Follows the close-and-stop the bot reports (`StatusV1.stopProgress`) across status reads: the
/// status holds only the current step's start, so the starts of earlier steps are the ones read
/// before. Also keeps the command's id after its progress is gone, so its refusal can be said.
public struct StopWatch: Equatable, Sendable {
  /// The steps in the order the bot goes through them (docs/api.md, stop-bot "Progress").
  public static let order: [StopStep] = [.closingPositions, .positionsClosed, .stopping, .stopped]

  /// The close-and-stop followed, by command id; nil before the first one.
  public private(set) var commandId: String?
  /// When each step of it began, as read.
  public private(set) var starts: [StopStep: Date] = [:]

  public init() {}

  /// Takes a status read: a close-and-stop's step and its start are kept; a new command starts
  /// over. Any other status leaves what was kept.
  public mutating func read(_ status: StatusV1?) {
    guard let progress = status?.stopProgress, progress.mode == .closeAndStop else { return }
    if progress.commandId != commandId {
      commandId = progress.commandId
      starts = [:]
    }
    starts[progress.step] = starts[progress.step] ?? progress.since.date
  }

  /// Forgets the followed command (a new command was pressed, or the bot started again).
  public mutating func forget() {
    commandId = nil
    starts = [:]
  }

  /// The four steps while `status` shows a close-and-stop (also once the bot stopped after it);
  /// nil otherwise, and the bot's normal controls show.
  public func steps(_ status: StatusV1?) -> [StopStepRow]? {
    guard let progress = status?.stopProgress, progress.mode == .closeAndStop,
      let current = Self.order.firstIndex(of: progress.step) else { return nil }
    return Self.order.enumerated().map { index, step -> StopStepRow in
      let phase: StopStepRow.Phase
      if index > current {
        phase = .waiting
      } else if index == current && (step == .closingPositions || step == .stopping) {
        phase = .running
      } else {
        phase = .done
      }
      // The current step's start is in the status; an earlier one's only if this watch read it.
      let since: Date?
      if index == current {
        since = progress.since.date
      } else if index < current && progress.commandId == commandId {
        since = starts[step]
      } else {
        since = nil
      }
      return StopStepRow(step: step, phase: phase, since: since)
    }
  }

  /// Why the followed close-and-stop was refused, in the person's language, once its progress is
  /// gone and the bot's record of it says refused; nil otherwise.
  public func refusal(_ status: StatusV1?) -> String? {
    guard let status, let commandId, status.stopProgress?.commandId != commandId,
      let record = status.recentCommands.first(where: { $0.commandId == commandId }),
      record.outcome == .refused else { return nil }
    return String(localized: StopText.refused(record.causeText ?? ApiText.missing))
  }
}

/// The panel of a bot stopped with positions open (boards Main and IOSHome, "Bot stopped · N
/// positions open"): what the stopped bot's last status says, with that status's times.
public struct StoppedPositions: Equatable, Sendable {
  /// One position as the stopped bot last knew it.
  public struct Row: Equatable, Sendable, Identifiable {
    public let symbol: String
    public let quantity: Decimal
    /// The broker stop's price; nil when the bot did not know it.
    public let stop: Decimal?
    public var id: String { symbol }
  }

  public let rows: [Row]
  /// When the bot stopped: its stop step's start, else when it wrote its last status.
  public let stoppedAt: Date
  /// When the bot last read the broker (the positions are as of then); nil when it never did.
  public let readAt: Date?

  /// The panel while `status` says the bot is stopped with positions open; nil otherwise.
  public static func make(_ status: StatusV1?) -> StoppedPositions? {
    guard let status, status.botState == .stopped, !status.positions.isEmpty else { return nil }
    let stop = status.stopProgress.flatMap { $0.step == .stopped ? $0.since.date : nil }
    return StoppedPositions(
      rows: status.positions.map { Row(symbol: $0.symbol, quantity: $0.quantity.value, stop: $0.stop.price?.value) },
      stoppedAt: stop ?? status.writtenAt.date,
      readAt: status.freshness.lastBrokerReadAt?.date)
  }

  /// The panel's title: "Bot stopped · 2 positions open".
  public var title: LocalizedStringResource { StopText.stoppedOpen(rows.count) }

  /// The line under the title: "stopped at 10:48:02 ET".
  public var since: LocalizedStringResource { StopText.stoppedAt(ClockText.seconds(stoppedAt)) }

  /// The line under the rows: the broker read time, or that it is not known.
  public var note: LocalizedStringResource {
    readAt.map { StopText.lastKnown(ClockText.seconds($0)) } ?? StopText.lastKnownUnknown
  }
}
