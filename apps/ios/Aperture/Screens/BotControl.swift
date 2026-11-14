import ApertureKit
import SwiftUI

/// The bot actions behind the power button (an action sheet, as iOS does for a set of related
/// actions). Commands that cancel orders or close positions ask for Face ID first.
struct BotControl: ViewModifier {
  @Environment(AppModel.self) private var model
  @Binding var isPresented: Bool

  func body(content: Content) -> some View {
    content.confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
      if let status = model.status, model.canCommand {
        if status.entryStop {
          Button("Resume Entries") { run(.entryStop(on: false)) }
        } else {
          Button("Pause Entries") { run(.entryStop(on: true)) }
        }
        Button("Cancel Own Orders") { run(.cancelOwnOrders) }
        Button("Flatten All Positions", role: .destructive) { run(.flatten) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Pausing and cancelling never touch broker stops. Flatten closes the bot's own "
        + "positions through the normal exit. Each command is queued once; the bot reports the result.")
    }
  }

  private var title: String {
    guard let status = model.status else { return "Bot status unknown" }
    let state = status.botState.rawValue
    return status.entryStop ? "Bot is \(state) · entries paused" : "Bot is \(state)"
  }

  private func run(_ command: OperatorCommand) {
    Task { await Self.confirmAndSend(command, model: model) }
  }

  /// Face ID for anything that cancels or closes; pausing and resuming entries is safe without it.
  /// The model checks freshness before and after Face ID.
  static func confirmAndSend(_ command: OperatorCommand, model: AppModel) async {
    let reason = "\(Board.commandTitle(command.kind)) on the trading bot"
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
