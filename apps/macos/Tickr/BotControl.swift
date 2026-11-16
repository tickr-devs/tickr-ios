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

  var title: String {
    switch self {
    case .pauseEntries: return String(localized: L10n.Bot.pauseEntries)
    case .resumeEntries: return String(localized: L10n.Bot.resumeEntries)
    case .cancelOrders: return String(localized: L10n.Bot.cancelOrders)
    case .flatten(let symbol): return String(localized: L10n.Bot.flatten(symbol))
    case .flattenAll: return String(localized: L10n.Bot.flattenAll)
    case .stopBot: return String(localized: L10n.Bot.stopBot)
    case .emergency: return String(localized: L10n.Bot.emergency)
    }
  }

  /// SF Symbols of the actions.
  static let pauseSymbol = "pause.fill"
  static let resumeSymbol = "play.fill"
  static let cancelSymbol = "xmark.circle"
  static let flattenSymbol = "rectangle.portrait.and.arrow.right"
  static let flattenAllSymbol = "rectangle.portrait.and.arrow.right.fill"
  static let stopSymbol = "stop.fill"
  static let emergencySymbol = "exclamationmark.octagon.fill"

  var symbol: String {
    switch self {
    case .pauseEntries: return Self.pauseSymbol
    case .resumeEntries: return Self.resumeSymbol
    case .cancelOrders: return Self.cancelSymbol
    case .flatten: return Self.flattenSymbol
    case .flattenAll: return Self.flattenAllSymbol
    case .stopBot: return Self.stopSymbol
    case .emergency: return Self.emergencySymbol
    }
  }

  /// The action's tone: resuming is the one positive action, the rest that close or stop are losses.
  var tone: Tone {
    switch self {
    case .resumeEntries: return .accent
    case .pauseEntries: return .warning
    case .cancelOrders: return .neutral
    case .flatten, .flattenAll, .stopBot, .emergency: return .loss
    }
  }

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

/// The bot control buttons. A press that asks first opens its question in the model
/// (`AppModel.press`); the window or panel around them shows it (`botCommandQuestions(in:)`).
/// Used on Overview and in the menu bar.
struct BotControls: View {
  @Environment(AppModel.self) private var model
  var compact = false
  /// Small labelled buttons, as the design draws them in the Overview's Safety card.
  var small = false
  /// Where the buttons stand, so their questions open there.
  var place = CommandPlace.window

  /// Button columns in the menu-bar panel and on Overview.
  static let compactColumns = 3
  static let columns = 2

  var body: some View {
    let count = compact ? Self.compactColumns : Self.columns
    let list = actions
    // A plain Grid, not a lazy one: the few buttons always exist, so they stay reachable (and
    // visible to accessibility) while scrolled out of view.
    let rows = stride(from: 0, to: list.count, by: count).map { Array(list[$0..<min($0 + count, list.count)]) }
    if compact {
      // The menu-bar panel: one toolbar of symbols; each names itself in its hint.
      IconToolbar {
        ForEach(list) { action in
          button(action)
        }
      }
    } else {
      Grid(horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.s) {
        ForEach(rows.indices, id: \.self) { index in
          GridRow {
            ForEach(rows[index]) { action in
              button(action)
            }
          }
        }
      }
    }
  }

  /// A confirmation's message with where the command goes: the demo day or the bot.
  static func confirmation(_ explanation: String, demo: Bool) -> LocalizedStringResource {
    demo ? L10n.Bot.confirmToDemo(explanation) : L10n.Bot.confirmToBot(explanation)
  }

  @ViewBuilder private func button(_ action: BotAction) -> some View {
    let tap = { model.press(action, in: place) }
    if compact {
      Button(role: action.isDestructive ? .destructive : nil, action: tap) {
        Label { Text(verbatim: action.title) } icon: { Image(systemName: action.symbol) }
      }
      .buttonStyle(.icon(action.tone))
      .disabled(!model.commandsEnabled || !applicable(action))
      .hint(verbatim: action.title)
      .accessibilityIdentifier(action.id)
    } else {
      Button(role: action.isDestructive ? .destructive : nil, action: tap) {
        Label {
          Text(verbatim: action.needsConfirmation ? "\(action.title)…" : action.title)
            .lineLimit(1)
            .minimumScaleFactor(Tokens.Shrink.slight)
        } icon: {
          Image(systemName: action.symbol)
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.action(kind(action), size: small ? .compact : .regular))
      .disabled(!model.commandsEnabled || !applicable(action))
      .hint(verbatim: action.explanation)
      .accessibilityIdentifier(action.id)
    }
  }

  /// Resuming entries is the main action when entries are paused; the rest are commands.
  private func kind(_ action: BotAction) -> ActionButtonStyle.Kind {
    switch action {
    case .resumeEntries: return .primary
    case _ where action.isDestructive: return .destructive
    default: return .secondary
    }
  }

  private var actions: [BotAction] {
    let paused = model.status?.entryStop ?? false
    var list: [BotAction] = [paused ? .resumeEntries : .pauseEntries, .cancelOrders]
    if compact {
      list += [.flattenAll, .emergency]
    } else {
      list += model.positions.map { .flatten(symbol: $0.position.symbol) }
      list += [.flattenAll, .stopBot, .emergency]
    }
    return list
  }

  private func applicable(_ action: BotAction) -> Bool {
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
        } label: { Text(verbatim: asked.action.title) }
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
