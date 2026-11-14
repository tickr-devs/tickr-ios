import ApertureKit
import SwiftUI

/// The bot actions behind the power button (an action sheet, as iOS does for a set of related
/// actions). Commands that cancel orders or close positions ask for Face ID first.
struct BotControl: ViewModifier {
  @Environment(AppModel.self) private var model
  @Binding var isPresented: Bool

  func body(content: Content) -> some View {
    content.confirmationDialog(Text(title), isPresented: $isPresented, titleVisibility: .visible) {
      if let status = model.status, model.canCommand {
        if status.entryStop {
          Button { run(.entryStop(on: false)) } label: { Text(L10n.Control.resume) }
        } else {
          Button { run(.entryStop(on: true)) } label: { Text(L10n.Control.pause) }
        }
        Button { run(.cancelOwnOrders) } label: { Text(L10n.Control.cancelOrders) }
        Button(role: .destructive) { run(.flatten) } label: { Text(L10n.Control.flattenAll) }
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

  private func run(_ command: OperatorCommand) {
    Task { await Self.confirmAndSend(command, model: model) }
  }

  /// Face ID for anything that cancels or closes; pausing and resuming entries is safe without it.
  /// The model checks freshness before and after Face ID.
  static func confirmAndSend(_ command: OperatorCommand, model: AppModel) async {
    let reason = String(localized: L10n.Control.reason(Board.commandTitle(command.kind)))
    let needsOwner = command == .cancelOwnOrders || command == .flatten
    if needsOwner {
      await model.send(command, confirmOwner: { await Biometrics.confirm(reason) })
    } else {
      await model.send(command)
    }
  }
}

extension View {
  func botControl(isPresented: Binding<Bool>) -> some View {
    modifier(BotControl(isPresented: isPresented))
  }
}
