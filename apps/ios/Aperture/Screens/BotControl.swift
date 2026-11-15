import ApertureDesign
import ApertureKit
import SwiftUI

/// The bot actions behind the power button, in a sheet with a clear Cancel. Commands that cancel orders or close positions ask for Face ID first.
struct BotControl: ViewModifier {
  @Environment(AppModel.self) private var model
  @Binding var isPresented: Bool
  /// A command that cannot be undone from the phone, waiting for its own confirmation.
  @State private var severe: OperatorCommand?
  /// The action chosen in the sheet, run once the sheet has gone so its alert can show.
  @State private var chosen: (() -> Void)?

  func body(content: Content) -> some View {
    content
      .alert(Text(severeTitle), isPresented: Binding(get: { severe != nil }, set: { if !$0 { severe = nil } }),
        presenting: severe) { command in
        Button(role: .destructive) { run(command) } label: { Text(severeAction(command)) }
        Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
      } message: { command in
        Text(severeMessage(command))
      }
      // A sheet, not a confirmation dialog: on iOS 26 a dialog turns into a popover without its
      // Cancel button, pointing away from the power button.
      .sheet(isPresented: $isPresented, onDismiss: {
        chosen?()
        chosen = nil
      }) {
        sheet
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
  }

  /// The bot's state, one line on what the actions do to broker stops, the actions and Cancel.
  private var sheet: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        Text(title)
          .font(.headline)
          .foregroundStyle(Palette.textPrimary)
        Text(L10n.Control.short)
          .font(.footnote)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
        if let status = model.status, model.canCommand {
          VStack(spacing: Tokens.Space.s) {
            if status.entryStop {
              action(L10n.Control.resume, role: nil) { run(.entryStop(on: false)) }
            } else {
              action(L10n.Control.pause, role: nil) { run(.entryStop(on: true)) }
            }
            action(L10n.Control.cancelOrders, role: nil) { run(.cancelOwnOrders) }
            action(L10n.Control.flattenAll, role: .destructive) { run(.flatten) }
            if status.botState == .running {
              action(L10n.Control.stopBot, role: .destructive) { severe = .stopBot }
            }
            action(L10n.Control.emergency, role: .destructive) { severe = .emergency }
          }
        }
        Button(role: .cancel) { isPresented = false } label: {
          Text(L10n.Common.cancel)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.iconWell)
        }
        .buttonStyle(.bordered)
      }
      .padding(Tokens.Space.l)
    }
    .background(Palette.background)
  }

  /// One action across the sheet; it runs once the sheet has closed.
  private func action(_ title: LocalizedStringResource, role: ButtonRole?, _ perform: @escaping () -> Void)
    -> some View {
    Button(role: role) {
      chosen = perform
      isPresented = false
    } label: {
      Text(title)
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.iconWell)
    }
    .buttonStyle(.bordered)
    .tint(role == .destructive ? Palette.loss : Palette.info)
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
