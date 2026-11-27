import SwiftUI
import TickrDesign
import TickrKit

/// An operator action as the app offers it. Each maps to one local-API command.
enum BotAction: Identifiable, Equatable {
  case pauseEntries, resumeEntries, flatten(symbol: String), closeAll, stopBot
  /// Cancel one working entry order (mockup v160): the row it was pressed on.
  case cancelEntry(EntryRow)

  /// Ids of the actions (SwiftUI identity only); a flatten action's id ends with its symbol.
  static let pauseID = "pause"
  static let resumeID = "resume"
  static let flattenPrefix = "flatten-"
  static let closeAllID = "close-all"
  static let stopID = "stop"
  static let cancelEntryPrefix = "cancel-entry-"

  var id: String {
    switch self {
    case .pauseEntries: return Self.pauseID
    case .resumeEntries: return Self.resumeID
    case .flatten(let symbol): return Self.flattenPrefix + symbol
    case .closeAll: return Self.closeAllID
    case .stopBot: return Self.stopID
    case .cancelEntry(let row): return Self.cancelEntryPrefix + row.symbol
    }
  }

  /// The API command the action sends. Close all is the API's emergency command: entries paused,
  /// the bot's working entry orders cancelled, every own position closed (docs/api.md).
  var command: OperatorCommand {
    switch self {
    case .pauseEntries: return .entryStop(on: true)
    case .resumeEntries: return .entryStop(on: false)
    case .flatten(let symbol): return .flattenSymbol(symbol)
    case .closeAll: return .emergency
    case .stopBot: return .stopBot
    case .cancelEntry(let row): return .cancelEntry(row.symbol)
    }
  }

  /// The action's name, as its button shows it (in the view's language).
  var label: LocalizedStringResource {
    switch self {
    case .pauseEntries: return L10n.Bot.pauseEntries
    case .resumeEntries: return L10n.Bot.resumeEntries
    case .flatten(let symbol): return L10n.Bot.flatten(symbol)
    case .closeAll: return L10n.Bot.flattenAll
    case .stopBot: return L10n.Bot.stopBot
    case .cancelEntry: return EntryText.cancel
    }
  }

  var title: String { String(localized: label) }

  /// Whether `command` is this action's send: Stop bot's also with a mode.
  func sends(_ command: OperatorCommand) -> Bool {
    command == self.command || (self == .stopBot && command.kind == .stopBot)
  }

  /// What the button says while the command is on its way: Close all is closing the positions
  /// (its pause and cancel come first and are quick), the rest as the command says it.
  var inFlightTitle: LocalizedStringResource {
    switch self {
    case .closeAll: return OperatorCommand.flatten.inFlightTitle
    default: return command.inFlightTitle
    }
  }

  /// SF Symbols of the actions (Pause draws `Symbols.pause`).
  static let resumeSymbol = "play.fill"
  static let flattenSymbol = "rectangle.portrait.and.arrow.right"
  static let stopSymbol = "stop.circle"

  var symbol: String {
    switch self {
    case .pauseEntries: return Symbols.pause
    case .resumeEntries: return Self.resumeSymbol
    case .flatten, .closeAll: return Self.flattenSymbol
    case .stopBot: return Self.stopSymbol
    case .cancelEntry: return EntryLook.cancelSymbol
    }
  }

  /// The action's look among the commands: pausing and resuming are secondary, their glyph in the
  /// action's tone (amber pause, teal resume); the rest close or stop and are destructive.
  var tier: CommandButtonStyle.Tier {
    switch self {
    case .resumeEntries: return .secondary(.accent)
    case .pauseEntries: return .secondary(.warning)
    case .flatten, .closeAll, .stopBot, .cancelEntry: return .destructive
    }
  }

  var isDestructive: Bool {
    switch self {
    case .flatten, .closeAll, .stopBot, .cancelEntry: return true
    case .pauseEntries, .resumeEntries: return false
    }
  }

  /// Pausing and resuming are reversible and act at once; the rest ask first.
  var needsConfirmation: Bool { isDestructive }

  var question: String {
    switch self {
    case .pauseEntries: return String(localized: L10n.Bot.pauseQuestion)
    case .resumeEntries: return String(localized: L10n.Bot.resumeQuestion)
    case .flatten(let symbol): return String(localized: L10n.Bot.flattenQuestion(symbol))
    case .closeAll: return String(localized: L10n.Bot.flattenAllQuestion)
    case .stopBot: return String(localized: L10n.Bot.stopQuestion)
    case .cancelEntry(let row): return String(localized: EntryText.question(row.symbol))
    }
  }

  var explanation: String {
    switch self {
    case .pauseEntries:
      return String(localized: L10n.Bot.pauseExplanation)
    case .resumeEntries:
      return String(localized: L10n.Bot.resumeExplanation)
    case .flatten:
      return String(localized: L10n.Bot.flattenExplanation) + " " + String(localized: L10n.Common.tradesAndDaysHint)
    case .closeAll:
      return String(localized: L10n.Bot.closeAllExplanation)
    case .stopBot:
      return String(localized: L10n.Bot.stopExplanation)
    case .cancelEntry(let row):
      return String(localized: EntryText.explanation(Shares.text(row.quantity), Money.price(row.limitPrice)))
    }
  }

  /// The question's answer that sends nothing: Keep for a working entry (mockup v160), Cancel
  /// for the rest.
  var keepLabel: LocalizedStringResource {
    if case .cancelEntry = self { return EntryText.keep }
    return L10n.Common.cancel
  }
}

/// Where a bot command was pressed: the main window or the menu-bar panel. Each presents only
/// its own questions, so one press never asks twice.
enum CommandPlace: Sendable, Hashable {
  case window, menuBar
}

/// A bot command waiting for the operator's yes (`AppModel.confirming`). Each press asks anew:
/// two presses of the same command are two questions, never one carried over.
struct PendingConfirmation: Identifiable, Equatable {
  let id = UUID()
  let action: BotAction
  let place: CommandPlace
  /// Stop bot with positions open asks to choose (Close and stop, Leave open); every other
  /// question is a plain yes.
  var stop: StopQuestion = .confirm
}

/// The Safety card's two commands side by side, as the design draws them: Pause entries (Resume
/// entries while paused) and Stop bot. Closing positions lives on the Positions card (each
/// position's Close and Close all in its header). A press that asks first opens its question in
/// the model (`AppModel.press`); the window around them shows it (`botCommandQuestions(in:)`). No
/// title is ever cut: the two go one under the other when their titles do not fit side by side,
/// and a title wraps as a last resort.
struct BotControls: View {
  @Environment(AppModel.self) private var model

  /// Columns of the row, as in the design.
  static let columns = 2

  var body: some View {
    CommandColumns(columns: Self.columns) {
      BotCommandButton(action: model.pauseAction, place: .window, size: .regular)
      BotCommandButton(action: .stopBot, place: .window, size: .regular)
    }
  }

  /// A confirmation's message with where the command goes: the demo day or the bot.
  static func confirmation(_ explanation: String, demo: Bool) -> LocalizedStringResource {
    demo ? L10n.Bot.confirmToDemo(explanation) : L10n.Bot.confirmToBot(explanation)
  }
}

/// Close all in the Positions card's header (mockup Main): shown while a position is open, it
/// asks first and then sends the API's emergency command (`BotAction.closeAll`).
struct CloseAllButton: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    // Not on a stopped bot's positions: its panel stands in their place.
    if !model.positions.isEmpty && model.stoppedPositions == nil {
      BotCommandButton(action: .closeAll, place: .window, size: .small)
        // A few words: always whole, on one line.
        .fixedSize()
    }
  }
}

/// Cancel entry (mockup v160): asks first, then sends cancel-own-orders for the entry's symbol
/// (`BotAction.cancelEntry`). Off while its cancel is on its way.
struct CancelEntryButton: View {
  let row: EntryRow

  var body: some View {
    BotCommandButton(action: .cancelEntry(row), place: .window, size: .small)
      .disabled(row.phase != .working)
  }
}

/// One bot command in its tier, with the "DEMO" pill while commands go to the demo day. A close
/// command is off without an open position, and says so. Every press goes through
/// `AppModel.press`, so each asks first exactly as the others do.
struct BotCommandButton: View {
  @Environment(AppModel.self) private var model
  let action: BotAction
  let place: CommandPlace
  let size: CommandButtonStyle.Size
  /// A shorter title in place of the action's own (the position panel's "Close ABCD").
  var title: LocalizedStringResource?
  /// Accessibility id in place of the action's, for a second button of the same command.
  var identifier: String?

  var body: some View {
    Button(role: action.isDestructive ? .destructive : nil) {
      model.press(action, in: place)
    } label: {
      Label { Text(title ?? action.label) } icon: { Image(systemName: action.symbol) }
    }
    .buttonStyle(.command(action.tier, size: size, tag: model.demoDay ? Text(L10n.Bot.demoTag) : nil))
    .disabled(!model.commandsEnabled || !applicable)
    .inFlight(inFlightTitle.map { Text($0) })
    // An off close command says why; the rest say what they do.
    .hint(verbatim: applicable ? action.explanation : String(localized: L10n.Bot.noPositions))
    .accessibilityIdentifier(identifier ?? action.id)
  }

  /// What the button says while its command is on its way: Stop bot says its mode's words.
  private var inFlightTitle: LocalizedStringResource? {
    guard let command = model.inFlight, action.sends(command) else { return nil }
    return action == .stopBot ? command.inFlightTitle : action.inFlightTitle
  }

  private var applicable: Bool {
    switch action {
    case .flatten, .closeAll: return !model.positions.isEmpty
    default: return true
    }
  }
}

/// Shows the bot command questions asked in `place` (`AppModel.confirming`) as standard alerts.
/// Put on a view that lives as long as its window, never on the buttons: SwiftUI rebuilds the
/// buttons' cards as the layout changes, and a question attached to them closed with them.
private struct BotCommandQuestions: ViewModifier {
  @Environment(AppModel.self) private var model
  let place: CommandPlace

  func body(content: Content) -> some View {
    let question = model.confirming.flatMap { $0.place == place && $0.stop == .confirm ? $0 : nil }
    let choice = model.confirming.flatMap { $0.place == place && $0.stop != .confirm ? $0 : nil }
    content
      // The alert closes its binding around its buttons' actions, in an order SwiftUI does not
      // promise; the question is closed by its buttons instead (Escape is the cancel button), so
      // the yes is always read against the question still open.
      .alert(Text(verbatim: question?.action.question ?? ""), isPresented: Binding(get: { question != nil },
        set: { _ in }), presenting: question) { asked in
        Button(role: asked.action.isDestructive ? .destructive : nil) {
          model.accept(asked)
        } label: { Text(asked.action.label) }
        Button(role: .cancel) { model.withdraw(asked) } label: { Text(asked.action.keepLabel) }
      } message: { asked in
        // Where the command goes, named in every confirmation: a demo switch left on must never
        // swallow a real command unnoticed.
        Text(BotControls.confirmation(asked.action.explanation, demo: model.demoDay))
      }
      // Stop bot with positions open (boards Main, MainNarrow): three buttons, Escape cancels.
      .alert(Text(verbatim: choice.map { StopChoice.title($0.stop) } ?? ""), isPresented: Binding(get: { choice != nil },
        set: { _ in }), presenting: choice) { asked in
        Button(role: .destructive) { model.accept(asked, mode: .closeAndStop) } label: { Text(StopText.closeAndStop) }
          .accessibilityIdentifier(StopChoice.closeAndStopID)
        Button { model.accept(asked, mode: .leaveOpen) } label: { Text(StopText.leaveOpen) }
          .accessibilityIdentifier(StopChoice.leaveOpenID)
        Button(String(localized: L10n.Common.cancel), role: .cancel) { model.withdraw(asked) }
      } message: { asked in
        Text(BotControls.confirmation(StopChoice.explanation(asked.stop), demo: model.demoDay))
      }
      // A question lives only while its window or panel does: closed, or opened anew, it holds no
      // question from before (a question never reappears without a new press).
      .onAppear { model.withdrawQuestion(in: place) }
      .onDisappear { model.withdrawQuestion(in: place) }
  }
}

extension View {
  /// Shows the bot command questions asked in `place` (`BotCommandQuestions`).
  func botCommandQuestions(in place: CommandPlace) -> some View {
    modifier(BotCommandQuestions(place: place))
  }
}

extension AppModel {
  /// Pause entries, or Resume entries while the operator's pause is on: the one pause command
  /// of the Safety card and the menu bar.
  var pauseAction: BotAction { status?.entryStop == true ? .resumeEntries : .pauseEntries }

  /// The bot's working entries on the live day, with where each one's cancel stands, and those
  /// just cancelled (`EntryCancelWatch`).
  var entryRows: [EntryRow] { isLive ? entryWatch.rows(status, inFlight: inFlight) : [] }

  /// The slots in use of `limit`, a working entry holding one as the engine counts it, with how
  /// many are pending: "2 of 3 · 1 pending".
  func slotsText(_ limit: Int) -> String {
    guard isLive, let status else { return String(localized: L10n.Common.countOf(positions.count, limit)) }
    return Slots.withPending(String(localized: L10n.Common.countOf(Slots.used(status), limit)), status)
  }
}
