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

/// The bot control buttons with standard confirmation alerts. Used on Overview and in the menu bar.
struct BotControls: View {
  @Environment(AppModel.self) private var model
  @State private var confirming: BotAction?
  var compact = false

  /// Button columns in the menu-bar panel and on Overview.
  static let compactColumns = 3
  static let columns = 2

  var body: some View {
    let count = compact ? Self.compactColumns : Self.columns
    let list = actions
    // A plain Grid, not a lazy one: the few buttons always exist, so they stay reachable (and
    // visible to accessibility) while scrolled out of view.
    let rows = stride(from: 0, to: list.count, by: count).map { Array(list[$0..<min($0 + count, list.count)]) }
    Group {
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
    .alert(Text(verbatim: confirming?.question ?? ""), isPresented: Binding(get: { confirming != nil },
      set: { if !$0 { confirming = nil } }),
      presenting: confirming) { action in
      Button(role: action.isDestructive ? .destructive : nil) { run(action) } label: { Text(verbatim: action.title) }
      Button(String(localized: L10n.Common.cancel), role: .cancel) {}
    } message: { action in
      Text(verbatim: action.explanation)
    }
    // Close an open confirmation as soon as commands are no longer safe to send.
    .onChange(of: model.commandsEnabled) { _, enabled in
      if !enabled { confirming = nil }
    }
  }

  @ViewBuilder private func button(_ action: BotAction) -> some View {
    let tap = {
      if action.needsConfirmation { confirming = action } else { run(action) }
    }
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
      .buttonStyle(.action(kind(action)))
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

  private func run(_ action: BotAction) {
    Task { await model.send(action.command, title: action.title) }
  }
}
