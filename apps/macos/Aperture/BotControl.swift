import ApertureDesign
import ApertureKit
import SwiftUI

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

  /// Smallest a button's title shrinks to before it truncates, as a share of its size.
  static let titleMinimumScale = 0.8
  /// Button columns in the menu-bar panel and on Overview.
  static let compactColumns = 3
  static let columns = 2

  var body: some View {
    let count = compact ? Self.compactColumns : Self.columns
    let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s), count: count)
    LazyVGrid(columns: columns, spacing: Tokens.Space.s) {
      ForEach(actions) { action in
        Button(role: action.isDestructive ? .destructive : nil) {
          if action.needsConfirmation { confirming = action } else { run(action) }
        } label: {
          HStack(spacing: Tokens.Space.xs) {
            Text(verbatim: action.needsConfirmation ? "\(action.title)…" : action.title)
              .lineLimit(1)
              .minimumScaleFactor(Self.titleMinimumScale)
          }
          .frame(maxWidth: .infinity)
        }
        .controlSize(compact ? .regular : .large)
        .tint(action.isDestructive ? Palette.loss : nil)
        .disabled(!model.commandsEnabled || !applicable(action))
        .help(Text(verbatim: action.explanation))
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
