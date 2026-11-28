import Foundation

/// How alarming the current state is; drives colours and the menu-bar symbol.
public enum Severity: Int, Comparable, Sendable {
  case ok = 0, attention = 1, alarm = 2

  public static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
}

/// The one line a person reads first, plus its severity. Pure, so iOS and tests share it.
public struct Headline: Equatable, Sendable {
  public let text: String
  public let severity: Severity
  /// The bot is off, about to start or starting by its schedule (`BotRun`): an expected silence,
  /// told calmly (blue, mockup v190, page p-off), never as a fault.
  public let calm: Bool
  /// What a pulse or transition beside the headline marks: a change of it is a real change of
  /// state. Not `text`: a stale status's text counts its age, which grows with every read of the
  /// same stale status.
  public let pulse: Pulse
  /// Whether the bot's entry block is the unprotected-position fence itself, which the headline's
  /// "has no verified stop" already says.
  static func blocksForThisFence(_ status: StatusV1) -> Bool {
    status.entryBlock.map { FenceKind(rawValue: $0.cause) == .unprotected } ?? false
  }

  /// The line after the headline about a trusted status: the open positions (`detail(_:)`), "stops
  /// verified" after the holding headline, or why entries are off; nil without a trusted status.
  public let detail: String?

  /// The event key of `Headline.pulse`.
  public enum Pulse: Hashable, Sendable {
    /// The headline's words, which change only with the state they describe.
    case text(String)
    /// The status is stale, however old.
    case stale
  }

  /// `pulse` defaults to the text.
  public init(text: String, severity: Severity, calm: Bool = false, pulse: Pulse? = nil, detail: String? = nil) {
    self.text = text
    self.severity = severity
    self.calm = calm
    self.pulse = pulse ?? .text(text)
    self.detail = detail
  }

  /// `readFailed`: the last read of /status failed; it wins over an older good response. The
  /// headline says so in plain words; the failure's technical detail is the connection banner's
  /// (ConnectionState), behind its "Details".
  /// `run`: the bot's run by its schedule (`BotRun`) at `now`; off, starting or silent, it speaks
  /// for a status that did not come (nil keeps the stale status's alarm).
  public static func make(response: StatusResponseV1?, readFailed: Bool, run: BotRun? = nil, now: Date = .now)
    -> Headline {
    if readFailed {
      return Headline(text: String(localized: L10n.headlineNoConnection), severity: .alarm)
    }
    guard let response else {
      return Headline(text: String(localized: L10n.headlineConnecting), severity: .attention)
    }
    if let run, let headline = run.headline(lastAnswer: response.status?.writtenAt.date, now: now) {
      return headline
    }
    guard let status = response.status, !response.stale else {
      let text = summary(response)
      return Headline(text: text, severity: .alarm, pulse: response.stale ? .stale : .text(text))
    }
    if let position = status.positions.first(where: { !$0.stop.state.isProtected }) {
      // The bot's block is usually this same fence ("A position has no verified stop"): said once.
      let start = String(localized: L10n.headlineNoVerifiedStop(position.symbol, Board.stopStateTitle(position.stop.state)))
      return Headline(
        text: blocksForThisFence(status) ? start.trimmingCharacters(in: .whitespaces) : start + summary(response),
        severity: .alarm, detail: detail(status))
    }
    // Below an alarm (mockup v109): a block that needs the operator, then held positions, then a
    // trading gate closed in config, then the calm rest. The closed gate is a setting, not a fault:
    // it never warns, and its grey badge beside the headline says it even while positions are held.
    let gateClosed = status.entryBlock.map { BlockCode(rawValue: $0.cause) == .tradingGateClosed } ?? false
    if status.entryBlock?.attention == true, !gateClosed {
      return Headline(text: summary(response), severity: .attention, detail: detail(status))
    }
    // Open positions, all protected and nothing for the operator to do: the headline says what
    // the bot holds, as on the design, not why a further entry would be refused.
    if !status.positions.isEmpty {
      let count = status.positions.count
      let text = count == 1 ? L10n.headlineHoldingOne : L10n.headlineHolding(count)
      let detail = count == 1 ? L10n.headlineStopVerified : L10n.headlineStopsVerified
      return Headline(text: String(localized: text), severity: .ok, detail: String(localized: detail))
    }
    if gateClosed {
      return Headline(text: String(localized: L10n.headlineEntriesOff), severity: .ok,
        detail: String(localized: L10n.headlineGateClosedInConfig))
    }
    // An ordinary refusal (outside the entry window) is calm.
    return Headline(text: summary(response), severity: .ok, detail: detail(status))
  }

  /// The line after the headline about a trusted status: how many positions are open and how
  /// many a verified broker stop protects, then how many own entry orders work (mockup v162); with
  /// none open, how many entry orders work, or that none is open.
  static func detail(_ status: StatusV1) -> String {
    let positions = Board.positions(status)
    guard !positions.isEmpty else {
      switch status.workingEntries.count {
      case 0: return String(localized: L10n.headlineNoOpenPosition)
      case 1: return String(localized: L10n.headlineEntryWorking)
      case let count: return String(localized: L10n.headlineEntriesWorking(count))
      }
    }
    let protected = positions.filter { $0.stop.state.isProtected }.count
    let entries = status.workingEntries.count
    guard entries > 0 else { return String(localized: L10n.headlineProtectedPositions(positions.count, protected)) }
    // With entries working the positions' part is the board's short one while every stop is
    // verified; otherwise it keeps saying how many are protected.
    let held = String(localized: protected < positions.count
      ? L10n.headlineProtectedPositions(positions.count, protected)
      : positions.count == 1 ? L10n.headlinePositionProtected : L10n.headlinePositionsProtected(positions.count))
    let working = String(localized: entries == 1 ? L10n.headlineEntryWorkingShort : L10n.headlineEntriesWorkingShort(entries))
    return String(localized: L10n.headlineWithEntries(held, working))
  }

  /// The bot's one-line summary in the person's language, built from the status as the bot builds
  /// its English `summary` (contract.summarize): the status's absence, its age, the entry block,
  /// or that entries are allowed.
  static func summary(_ response: StatusResponseV1) -> String {
    guard let status = response.status else {
      return String(localized: L10n.headlineUnavailable(response.unavailableCauseText ?? response.summary))
    }
    if response.stale {
      let seconds = response.ageSeconds.map { NSDecimalNumber(decimal: $0.value).intValue }
      return seconds.map { String(localized: L10n.headlineStale(Elapsed.text(seconds: $0))) } ?? response.summary
    }
    if let block = status.entryBlock { return ApiText.entryBlock(block) }
    return String(localized: L10n.headlineAllowed)
  }
}
