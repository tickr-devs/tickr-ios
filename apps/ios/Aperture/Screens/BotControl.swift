import ApertureKit
import SwiftUI

/// The bot actions behind the power button (an action sheet, as iOS does for a set of related
/// actions). Commands that cancel orders or close positions ask for Face ID first.
struct BotControl: ViewModifier {
  @Environment(AppModel.self) private var model
  @Binding var isPresented: Bool
  /// A command that cannot be undone from the phone, waiting for its own confirmation.
  @State private var severe: OperatorCommand?

  func body(content: Content) -> some View {
    content
      .alert(Text(severeTitle), isPresented: Binding(get: { severe != nil }, set: { if !$0 { severe = nil } }),
        presenting: severe) { command in
        Button(role: .destructive) { run(command) } label: { Text(severeAction(command)) }
        Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
      } message: { command in
        Text(severeMessage(command))
      }
      .confirmationDialog(Text(title), isPresented: $isPresented, titleVisibility: .visible) {
        if let status = model.status, model.canCommand {
          if status.entryStop {
            Button { run(.entryStop(on: false)) } label: { Text(L10n.Control.resume) }
          } else {
            Button { run(.entryStop(on: true)) } label: { Text(L10n.Control.pause) }
          }
          Button { run(.cancelOwnOrders) } label: { Text(L10n.Control.cancelOrders) }
          Button(role: .destructive) { run(.flatten) } label: { Text(L10n.Control.flattenAll) }
          if status.botState == .running {
            Button(role: .destructive) { severe = .stopBot } label: { Text(L10n.Control.stopBot) }
          }
          Button(role: .destructive) { severe = .emergency } label: { Text(L10n.Control.emergency) }
        }
        Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
      } message: {
        Text(L10n.Control.message)
      }
  }

  private var title: LocalizedStringResource {
    guard let status = model.status else { return L10n.Control.unknown }
    let state = String(localized: status.botState.title)
    return status.entryStop ? L10n.Control.statePaused(state) : L10n.Control.state(state)
  }

  private var severeTitle: LocalizedStringResource {
    severe == .emergency ? L10n.Control.emergencyTitle : L10n.Control.stopTitle
  }

  private func severeAction(_ command: OperatorCommand) -> LocalizedStringResource {
    command == .emergency ? L10n.Control.emergency : L10n.Control.stopBot
  }

  private func severeMessage(_ command: OperatorCommand) -> LocalizedStringResource {
    command == .emergency ? L10n.Control.emergencyWarning : L10n.Control.stopWarning
  }

  private func run(_ command: OperatorCommand) {
    Task { await Self.confirmAndSend(command, model: model) }
  }

  /// Face ID for anything that cancels, closes or stops; pausing and resuming entries is safe
  /// without it. The model checks freshness before and after Face ID.
  static func confirmAndSend(_ command: OperatorCommand, model: AppModel) async {
    let reason = String(localized: L10n.Control.reason(Board.commandTitle(command.kind)))
    if needsOwner(command) {
      await model.send(command, confirmOwner: { await Biometrics.confirm(reason) })
    } else {
      await model.send(command)
    }
  }

  /// Whether `command` needs the owner's Face ID or passcode: all but pausing and resuming entries.
  static func needsOwner(_ command: OperatorCommand) -> Bool {
    switch command {
    case .entryStop: return false
    case .cancelOwnOrders, .flatten, .flattenSymbol, .stopBot, .emergency: return true
    }
  }
}

extension View {
  func botControl(isPresented: Binding<Bool>) -> some View {
    modifier(BotControl(isPresented: isPresented))
  }
}
