import SwiftUI
import TickrDesign
import TickrKit

/// An operator action as the app offers it. Each maps to one local-API command.
enum BotAction: Identifiable, Equatable {
  case pauseEntries, resumeEntries, cancelOrders, flatten(symbol: String), flattenAll, stopBot, emergency

  /// Ids of the actions (SwiftUI identity only); a flatten action's id ends with its symbol.
  static let pauseID = "pause"
  static let resumeID = "resume"
  static let cancelID = "cancel"
  static let flattenPrefix = "flatten-"
  static let flattenAllID = "flatten-all"
  static let stopID = "stop"
  static let emergencyID = "emergency"

  var id: String {
    switch self {
    case .pauseEntries: return Self.pauseID
    case .resumeEntries: return Self.resumeID
    case .cancelOrders: return Self.cancelID
    case .flatten(let symbol): return Self.flattenPrefix + symbol
    case .flattenAll: return Self.flattenAllID
    case .stopBot: return Self.stopID
    case .emergency: return Self.emergencyID
    }
  }

  /// The API command the action sends.
  var command: OperatorCommand {
    switch self {
    case .pauseEntries: return .entryStop(on: true)
    case .resumeEntries: return .entryStop(on: false)
    case .cancelOrders: return .cancelOwnOrders
    case .flatten(let symbol): return .flattenSymbol(symbol)
    case .flattenAll: return .flatten
    case .stopBot: return .stopBot
    case .emergency: return .emergency
    }
  }

  /// The action's name, as its button shows it (in the view's language).
  var label: LocalizedStringResource {
    switch self {
    case .pauseEntries: return L10n.Bot.pauseEntries
    case .resumeEntries: return L10n.Bot.resumeEntries
    case .cancelOrders: return L10n.Bot.cancelOrders
    case .flatten(let symbol): return L10n.Bot.flatten(symbol)
    case .flattenAll: return L10n.Bot.flattenAll
    case .stopBot: return L10n.Bot.stopBot
    case .emergency: return L10n.Bot.emergency
    }
  }

  var title: String { String(localized: label) }

  /// SF Symbols of the actions (Pause draws `Symbols.pause`).
  static let resumeSymbol = "play.fill"
  static let cancelSymbol = "xmark.circle"
  static let flattenSymbol = "rectangle.portrait.and.arrow.right"
  static let flattenAllSymbol = "rectangle.portrait.and.arrow.right"
  static let stopSymbol = "stop.circle"
  static let emergencySymbol = "exclamationmark.octagon.fill"

  var symbol: String {
    switch self {
    case .pauseEntries: return Symbols.pause
    case .resumeEntries: return Self.resumeSymbol
    case .cancelOrders: return Self.cancelSymbol
    case .flatten: return Self.flattenSymbol
    case .flattenAll: return Self.flattenAllSymbol
    case .stopBot: return Self.stopSymbol
    case .emergency: return Self.emergencySymbol
    }
  }

  /// The action's look among the commands: pausing, resuming and cancelling are secondary, their
  /// glyph in the action's tone (amber pause, teal resume, muted cancel); the rest close or stop
  /// and are destructive. The emergency stop has its own button (`EmergencyButton`).
  var tier: CommandButtonStyle.Tier {
    switch self {
    case .resumeEntries: return .secondary(.accent)
    case .pauseEntries: return .secondary(.warning)
    case .cancelOrders: return .secondary(.neutral)
    case .flatten, .flattenAll, .stopBot, .emergency: return .destructive
    }
  }

  /// Only the emergency stop is held before it asks (`Tokens.Command.holdSeconds`): a click alone
  /// never opens its question, so a slip of the pointer cannot start it. The hold comes before the
  /// confirmation; it never replaces it.
  var holdsFirst: Bool { self == .emergency }

  var isDestructive: Bool {
    switch self {
    case .flatten, .flattenAll, .stopBot, .emergency: return true
    default: return false
    }
  }

  /// Pausing and resuming are reversible and act at once; the rest ask first.
  var needsConfirmation: Bool {
    switch self {
    case .pauseEntries, .resumeEntries: return false
    default: return true
    }
  }

  var question: String {
    switch self {
    case .pauseEntries: return String(localized: L10n.Bot.pauseQuestion)
    case .resumeEntries: return String(localized: L10n.Bot.resumeQuestion)
    case .cancelOrders: return String(localized: L10n.Bot.cancelQuestion)
    case .flatten(let symbol): return String(localized: L10n.Bot.flattenQuestion(symbol))
    case .flattenAll: return String(localized: L10n.Bot.flattenAllQuestion)
    case .stopBot: return String(localized: L10n.Bot.stopQuestion)
    case .emergency: return String(localized: L10n.Bot.emergencyQuestion)
    }
  }

  var explanation: String {
    switch self {
    case .pauseEntries:
      return String(localized: L10n.Bot.pauseExplanation)
    case .resumeEntries:
      return String(localized: L10n.Bot.resumeExplanation)
    case .cancelOrders:
      return String(localized: L10n.Bot.cancelExplanation)
    case .flatten:
      return String(localized: L10n.Bot.flattenExplanation) + " " + String(localized: L10n.Common.tradesAndDaysHint)
    case .flattenAll:
      return String(localized: L10n.Bot.flattenAllExplanation)
    case .stopBot:
      return String(localized: L10n.Bot.stopExplanation)
    case .emergency:
      return String(localized: L10n.Bot.emergencyExplanation)
    }
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
}

/// The bot control buttons, in the design's three tiers: pausing (or resuming) and cancelling,
/// then the commands that close positions, then the emergency stop alone behind its "Last resort"
/// divider. Stop bot stands in the Safety card's header (`BotStopButton`). A press that asks first opens its question in the model
/// (`AppModel.press`); the window or panel around them shows it (`botCommandQuestions(in:)`).
/// Used on Overview's Safety card and in the menu bar. No title is ever cut: commands go one under
/// another when their titles do not fit side by side, and a title wraps as a last resort.
struct BotControls: View {
  @Environment(AppModel.self) private var model
  /// The menu-bar panel's shorter commands, with only Close all in the second row.
  var compact = false
  /// Where the buttons stand, so their questions open there.
  var place = CommandPlace.window

  /// Columns of each row (pause and cancel; the close commands), as in the design.
  static let columns = 2

  var body: some View {
    let paused = model.status?.entryStop ?? false
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CommandColumns(columns: Self.columns) {
        button(paused ? .resumeEntries : .pauseEntries)
        button(.cancelOrders)
      }
      CommandColumns(columns: compact ? 1 : Self.columns) {
        ForEach(closing) { action in
          button(action)
        }
      }
      LastResortDivider(Text(L10n.Bot.lastResort))
      emergency
    }
  }

  /// A confirmation's message with where the command goes: the demo day or the bot.
  static func confirmation(_ explanation: String, demo: Bool) -> LocalizedStringResource {
    demo ? L10n.Bot.confirmToDemo(explanation) : L10n.Bot.confirmToBot(explanation)
  }

  /// The hold's length as the hints say it, in the person's number format ("1.5", "1,5").
  static var holdSeconds: String {
    Tokens.Command.holdSeconds.formatted(.number.precision(.fractionLength(1)))
  }

  private func button(_ action: BotAction) -> some View {
    BotCommandButton(action: action, place: place, size: compact ? .compact : .regular,
      detail: compact ? Self.detail(action, positions: model.positions.count) : nil)
  }

  /// The words after a menu-bar command's title, as the design's "2 positions" after Close all:
  /// how many positions it closes; nothing without one (the command is off then) and after the
  /// other commands.
  static func detail(_ action: BotAction, positions: Int) -> LocalizedStringResource? {
    guard case .flattenAll = action, positions > 0 else { return nil }
    return L10n.Bot.positionCount(positions)
  }

  private var emergency: some View {
    let action = BotAction.emergency
    let hold = action.holdsFirst ? EmergencyButton.Hold(prompt: Text(L10n.Bot.holdPrompt(Self.holdSeconds)),
      holding: Text(L10n.Bot.holding), accessibilityHint: Text(L10n.Bot.holdAccessibility(Self.holdSeconds))) : nil
    return EmergencyButton(Text(action.label), detail: Text(L10n.Bot.emergencyDetail), symbol: action.symbol,
      hold: hold, tag: model.demoDay ? Text(L10n.Bot.demoTag) : nil) {
      model.press(action, in: place)
    }
    .disabled(!model.commandsEnabled)
    .hint(verbatim: action.explanation)
    .accessibilityIdentifier(action.id)
  }

  /// The second row: one close command per open position, then Close all; the menu-bar panel has
  /// Close all only.
  private var closing: [BotAction] {
    if compact { return [.flattenAll] }
    return model.positions.map { .flatten(symbol: $0.position.symbol) } + [.flattenAll]
  }
}

/// Stop bot in the Safety card's header, beside the bot's state, as the design draws it.
struct BotStopButton: View {
  var body: some View {
    BotCommandButton(action: .stopBot, place: .window, size: .small)
      // A few words: always whole, on one line.
      .fixedSize()
  }
}

/// One bot command (not the emergency stop) in its tier, with the "DEMO" pill while commands go to
/// the demo day. A close command is off without an open position, and says so.
private struct BotCommandButton: View {
  @Environment(AppModel.self) private var model
  let action: BotAction
  let place: CommandPlace
  let size: CommandButtonStyle.Size
  /// A few words after the title (`BotControls.detail`).
  var detail: LocalizedStringResource?

  var body: some View {
    Button(role: action.isDestructive ? .destructive : nil) {
      model.press(action, in: place)
    } label: {
      Label { Text(action.label) } icon: { Image(systemName: action.symbol) }
    }
    .buttonStyle(.command(action.tier, size: size, detail: detail.map { Text($0) },
      tag: model.demoDay ? Text(L10n.Bot.demoTag) : nil))
    .disabled(!model.commandsEnabled || !applicable)
    // An off close command says why; the rest say what they do.
    .hint(verbatim: applicable ? action.explanation : String(localized: L10n.Bot.noPositions))
    .accessibilityIdentifier(action.id)
  }

  private var applicable: Bool {
    switch action {
    case .flatten, .flattenAll: return !model.positions.isEmpty
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
    let question = model.confirming.flatMap { $0.place == place ? $0 : nil }
    content
      // The alert closes its binding around its buttons' actions, in an order SwiftUI does not
      // promise; the question is closed by its buttons instead (Escape is the cancel button), so
      // the yes is always read against the question still open.
      .alert(Text(verbatim: question?.action.question ?? ""), isPresented: Binding(get: { question != nil },
        set: { _ in }), presenting: question) { asked in
        Button(role: asked.action.isDestructive ? .destructive : nil) {
          model.accept(asked)
        } label: { Text(asked.action.label) }
        Button(String(localized: L10n.Common.cancel), role: .cancel) { model.withdraw(asked) }
      } message: { asked in
        // Where the command goes, named in every confirmation: a demo switch left on must never
        // swallow a real command unnoticed.
        Text(BotControls.confirmation(asked.action.explanation, demo: model.demoDay))
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
