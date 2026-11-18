import Foundation

/// An order's leg as the bot names it (`Leg` in src/tickr/engine/core.py).
public enum OrderLeg: String, Sendable {
  case entry, stop, exit
}

/// How the bot ended a run (`run-ended` causes in src/tickr/cli.py); any other reads as stopped.
enum BotStop: String {
  case finished, interrupted, refused
  case deadline = "shutdown-deadline"

  /// An ordinary stop reads quiet; an interrupted or unfinished one amber.
  var calm: Bool { self != .deadline && self != .interrupted }
}

extension Board {
  /// Event ids of the day's journal: `journal-<seq>`.
  static let journalID = "journal-"
  /// Between a started strategy's name and version in `subject` ("price-action@3").
  static let versionSeparator: Character = "@"

  /// The day's events (GET /events) as journal lines, newest first, in the person's language;
  /// an event of a kind this app does not know is left out, never shown as its code. `price`
  /// formats a price (TickrDesign `Money.price`).
  public static func journal(_ document: DayEventsV1, price: (Decimal) -> String) -> [Event] {
    document.events.reversed().compactMap { line($0, price: price) }
  }

  /// A line's tag, text and tone.
  typealias LineParts = (tag: LocalizedStringResource, text: String, tone: Event.Tone)

  static func line(_ event: DayEventV1, price: (Decimal) -> String) -> Event? {
    guard let kind = event.event else { return nil }
    let parts = orderParts(kind, event, price: price) ?? otherParts(kind, event)
    return Event(id: "\(journalID)\(event.seq)", time: event.at.date, tag: String(localized: parts.tag),
      text: parts.text, tone: parts.tone)
  }

  /// A line about a trade's orders; nil for any other kind.
  static func orderParts(_ kind: DayEventKind, _ event: DayEventV1, price: (Decimal) -> String) -> LineParts? {
    let symbol = event.symbol
    let quantity = event.quantity.map { CheckValue.text($0.value) }
    let shown = event.price.map { price($0.value) }
    let stop = event.stopPrice.map { price($0.value) }
    let leg = event.leg.flatMap(OrderLeg.init(rawValue:))
    switch kind {
    case .entrySent:
      return (L10n.tagEnter, joined(quantityAt(symbol, quantity, shown),
        stop.map { String(localized: L10n.journalStopAt($0)) }), .teal)
    case .filled:
      return (filledTag(leg), quantityAt(symbol, quantity, shown), filledTone(leg))
    case .orderRefused:
      return (L10n.tagRefused, joined(symbol, String(localized: refusedText(leg))), leg == .stop ? .red : .amber)
    case .stopPlaced:
      return (L10n.journalStopPlaced, quantityAt(symbol, quantity, stop), .green)
    case .stopMoved:
      return (L10n.journalStopMoved, joined(symbol, stop.map { String(localized: L10n.journalTo($0)) }), .green)
    default:
      return nil
    }
  }

  /// A line about the bot, a trade's close, a fence or a command.
  static func otherParts(_ kind: DayEventKind, _ event: DayEventV1) -> LineParts {
    let symbol = event.symbol
    let cause = event.cause ?? ""
    switch kind {
    case .botStarted:
      return (L10n.journalBotOn, startedText(event.subject), .blue)
    case .botStopped:
      let stop = event.cause.flatMap(BotStop.init(rawValue:))
      return (L10n.journalBotOff, String(localized: stopTitle(stop)), stop?.calm ?? true ? .muted : .amber)
    case .exitRequested:
      return (L10n.journalExit, joined(symbol, exitReasonTitle(cause)), exitKind(cause) == .ordinary ? .blue : .amber)
    case .fenceSet, .fenceCleared:
      let title = String(localized: event.subject.flatMap(ApiText.fenceKindCase)?.title ?? L10n.fenceOther)
      return kind == .fenceSet
        ? (L10n.tagFence, joined(symbol, title), .amber) : (L10n.journalFenceCleared, joined(symbol, title), .green)
    case .commandDone, .commandRefused:
      let title = event.subject.flatMap(CommandKind.init(rawValue:)).map(commandTitle)
        ?? String(localized: L10n.journalCommandOther)
      return kind == .commandDone ? (L10n.tagDone, title, .blue) : (L10n.tagRefused, joined(title, event.causeText), .red)
    default:
      // A trade closed (the order kinds are `orderParts`').
      // An entry that never filled bought nothing: it did not close a position.
      let notFilled = ExitReason(rawValue: cause).map { [.entryNotFilled, .entryNotFilledInTime].contains($0) } ?? false
      return (notFilled ? L10n.journalNotFilled : L10n.journalClosed, joined(symbol, exitReasonTitle(cause)), closedTone(cause))
    }
  }

  static func filledTone(_ leg: OrderLeg?) -> Event.Tone {
    switch leg {
    case .entry: .teal
    case .exit: .blue
    case .stop, nil: .muted
    }
  }

  /// "ABCD 100 @ 4.12" (the cards' own wording) when all three are known, else the known ones.
  static func quantityAt(_ symbol: String?, _ quantity: String?, _ price: String?) -> String {
    guard let symbol, let quantity, let price else {
      return joined(symbol, quantity, price.map { String(localized: L10n.journalAt($0)) })
    }
    return String(localized: L10n.eventQuantityAt(symbol, quantity, price))
  }

  /// The present parts of a line, joined with " · ".
  static func joined(_ parts: String?...) -> String {
    parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: journalSeparator)
  }

  /// Between the parts of a journal line.
  static let journalSeparator = " · "

  static func startedText(_ subject: String?) -> String {
    guard let subject, let cut = subject.lastIndex(of: versionSeparator) else {
      return String(localized: L10n.journalStarted)
    }
    let name = String(subject[..<cut])
    let version = String(subject[subject.index(after: cut)...])
    return String(localized: L10n.journalStartedWith(name, version))
  }

  static func stopTitle(_ stop: BotStop?) -> LocalizedStringResource {
    switch stop {
    case .interrupted: L10n.journalInterrupted
    case .refused: L10n.journalRefusedStart
    case .deadline: L10n.journalDeadline
    case .finished, nil: L10n.journalStopped
    }
  }

  static func filledTag(_ leg: OrderLeg?) -> LocalizedStringResource {
    switch leg {
    case .entry: L10n.journalBought
    case .stop: L10n.journalStopFilled
    case .exit, nil: L10n.journalSold
    }
  }

  static func refusedText(_ leg: OrderLeg?) -> LocalizedStringResource {
    switch leg {
    case .entry: L10n.journalEntryRefused
    case .stop: L10n.journalStopRefused
    case .exit, nil: L10n.journalExitRefused
    }
  }

  /// A closed trade's tone without its result: red only when protection failed, amber for a
  /// forced close, otherwise quiet (a stop hit is an ordinary close, not a danger).
  static func closedTone(_ cause: String) -> Event.Tone {
    switch exitKind(cause) {
    case .protectionFailure: .red
    case .forced: .amber
    case .ordinary: .muted
    }
  }
}
