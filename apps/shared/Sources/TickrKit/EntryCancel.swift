import Foundation

// Cancel entry (mockup v160, "Proposal: cancel an entry order", approved 2026-11-26): an own entry
// order working with nothing filled, its Cancel entry and what follows, on Mac Overview and iPhone
// Home. Pure logic over the status; the views draw it.

/// One working entry as the apps show it: the order, and where its cancel stands.
public struct EntryRow: Equatable, Sendable, Identifiable {
  public enum Phase: Equatable, Sendable {
    /// Working at the broker, nothing filled: Cancel entry can be pressed.
    case working
    /// The operator's cancel is on its way, or the bot asked the broker and waits for its read.
    case cancelling
    /// A broker read showed the order gone with nothing filled; shown for a moment, then the
    /// card is empty again.
    case cancelled
  }

  public let symbol: String
  public let quantity: Decimal
  public let limitPrice: Decimal
  public let stopPrice: Decimal
  public let plannedLossUsd: Decimal
  /// When the entry order was sent; nil when the bot's journal does not say.
  public let sentAt: Date?
  public let phase: Phase
  /// The operator's last cancel of this entry was never picked up by the bot and can no longer
  /// run (older than `SettingsV1.commandMaxAgeSeconds`): the entry still works, Cancel entry can
  /// be pressed again, and the row says why it did not cancel. The limit in seconds; nil
  /// otherwise.
  public let cancelLapsedAfter: Decimal?

  public var id: String { symbol }

  public init(_ entry: WorkingEntry, phase: Phase, cancelLapsedAfter: Decimal? = nil) {
    symbol = entry.symbol
    quantity = entry.quantity.value
    limitPrice = entry.limitPrice.value
    stopPrice = entry.stopPrice.value
    plannedLossUsd = entry.plannedLossUsd.value
    sentAt = entry.entry.sentAt?.date
    self.phase = phase
    self.cancelLapsedAfter = cancelLapsedAfter
  }
}

/// Follows the bot's working entries across status reads (`StatusV1.workingEntries`), so the
/// apps can say "Cancelled at broker" once an entry the operator cancelled is gone. The status
/// lists only entries still working; that one went away is known only from the read before.
///
/// Gone means a broker read: the bot drops an entry from the list only when its order reads
/// terminal at the broker or partly filled. Partly filled makes a position in its symbol, and
/// that is never called cancelled.
public struct EntryCancelWatch: Equatable, Sendable {
  /// How long a cancelled entry stays on the card, in seconds (the approved mockup shows
  /// "Cancelled at broker" for about this long before the card is empty).
  public static let cancelledShownSeconds: TimeInterval = 3

  /// The entries of the last read, by symbol.
  private var seen: [String: WorkingEntry] = [:]
  /// The operator's queued cancels not yet settled: command id → the cancel.
  private var asked: [String: Ask] = [:]
  /// Symbols whose last cancel lapsed unpicked, with the limit it outlived (seconds).
  private var lapsed: [String: Decimal] = [:]
  /// Entries a read showed cancelled, with when it did.
  private var gone: [Gone] = []

  struct Ask: Equatable, Sendable {
    let symbol: String
    let requestedAt: Date
  }

  struct Gone: Equatable, Sendable {
    let entry: WorkingEntry
    let at: Date
  }

  public init() {}

  /// The API queued the operator's command: a cancel of one entry is followed from now on.
  public mutating func queued(_ command: CommandV1) {
    guard command.kind == .cancelOwnOrders, let symbol = command.symbol else { return }
    asked[command.commandId] = Ask(symbol: symbol, requestedAt: command.requestedAt.date)
    lapsed[symbol] = nil
  }

  /// Takes a status read at `now`. `commandMaxAge` is `SettingsV1.commandMaxAgeSeconds`: the bot
  /// refuses a command older than that as expired, so a cancel it has not picked up by then (the
  /// bot is stopped or not reading) can no longer run. Nil (an older API) follows a cancel until
  /// a read settles it.
  public mutating func read(_ status: StatusV1?, now: Date, commandMaxAge: Decimal? = nil) {
    guard let status else { return }
    let current = Dictionary(status.workingEntries.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
    let held = Set(status.positions.map(\.symbol))
    // A cancel the bot refused (no entry working by then, or any other cause) is no longer on
    // its way; its refusal is shown as every refused command's is.
    for record in status.recentCommands where record.outcome == .refused { asked[record.commandId] = nil }
    if let commandMaxAge {
      let processed = Set(status.recentCommands.map(\.commandId))
      let limit = NSDecimalNumber(decimal: commandMaxAge).doubleValue
      for (id, ask) in asked where !processed.contains(id) && now.timeIntervalSince(ask.requestedAt) > limit
        && current[ask.symbol]?.cancelRequested == false {
        asked[id] = nil
        lapsed[ask.symbol] = commandMaxAge
      }
    }
    let askedSymbols = Set(asked.values.map(\.symbol))
    for (symbol, entry) in seen where current[symbol] == nil {
      if !held.contains(symbol) && (entry.cancelRequested || askedSymbols.contains(symbol)) {
        gone.append(Gone(entry: entry, at: now))
      }
      asked = asked.filter { $0.value.symbol != symbol }
    }
    lapsed = lapsed.filter { current[$0.key]?.cancelRequested == false }
    gone.removeAll { now.timeIntervalSince($0.at) >= Self.cancelledShownSeconds
      || current[$0.entry.symbol] != nil || held.contains($0.entry.symbol) }
    seen = current
  }

  /// Forgets everything followed (the app switched to another bot).
  public mutating func forget() {
    seen = [:]
    asked = [:]
    lapsed = [:]
    gone = []
  }

  /// The rows to show for `status`: each working entry, then each one just cancelled.
  /// `inFlight` is the command the app is sending now.
  public func rows(_ status: StatusV1?, inFlight: OperatorCommand?) -> [EntryRow] {
    guard let status else { return [] }
    let askedSymbols = Set(asked.values.map(\.symbol))
    let working = status.workingEntries.map { entry in
      let cancelling = entry.cancelRequested || askedSymbols.contains(entry.symbol)
        || inFlight == .cancelEntry(entry.symbol)
      return cancelling ? EntryRow(entry, phase: .cancelling)
        : EntryRow(entry, phase: .working, cancelLapsedAfter: lapsed[entry.symbol])
    }
    let listed = Set(status.workingEntries.map(\.symbol))
    return working + gone.filter { !listed.contains($0.entry.symbol) }.map { EntryRow($0.entry, phase: .cancelled) }
  }
}
