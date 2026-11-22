import SwiftUI
import TickrDesign
import TickrKit

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
        Text(Self.target(String(localized: severeMessage(command)), demo: model.connection.demo))
      }
      // A sheet, not a confirmation dialog: on iOS 26 a dialog turns into a popover without its
      // Cancel button, pointing away from the power button.
      .sheet(isPresented: $isPresented, onDismiss: {
        chosen?()
        chosen = nil
      }, content: {
        // As tall as the state, the actions and Cancel: nothing waits below the fold, and only at
        // accessibility text sizes, taller than the screen, does it scroll.
        sheet
          .sheetFitsContent()
          .presentationCornerRadius(Self.sheetRadius)
      })
  }

  /// The bot's state, one line on what the actions do to broker stops, the actions and Cancel.
  private var sheet: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if model.connection.demo {
          WarningBanner(L10n.Home.demoTitle, detail: L10n.Home.demoDetail, systemImage: SettingsView.demoSymbol)
        }
        HStack(spacing: Tokens.Space.s) {
          StateGlyph(stateSymbol, tone: stateTone, label: title, live: model.status?.botState == .running,
            event: model.status?.botState, style: .round)
          Text(title)
            .font(.headline)
            .foregroundStyle(Palette.textPrimary)
        }
        Text(L10n.Control.short)
          .font(.footnote)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
        if let status = model.status, model.canCommand {
          // The design's three tiers: pausing (or resuming) and cancelling, then the commands that
          // close positions or stop the bot, then the emergency stop alone behind its divider.
          VStack(spacing: Tokens.Space.s) {
            if status.entryStop {
              action(L10n.Control.resume, symbol: Self.resumeSymbol, tier: .secondary(.accent)) {
                run(.entryStop(on: false))
              }
            } else {
              action(L10n.Control.pause, symbol: Symbols.pause, tier: .secondary(.warning)) {
                run(.entryStop(on: true))
              }
            }
            action(L10n.Control.cancelOrders, symbol: Self.cancelSymbol, tier: .secondary(.neutral)) {
              run(.cancelOwnOrders)
            }
            action(L10n.Control.flattenAll, symbol: Self.flattenSymbol, tier: .destructive) { run(.flatten) }
            if status.botState == .running {
              action(L10n.Control.stopBot, symbol: Self.stopSymbol, tier: .destructive) { severe = .stopBot }
            }
            LastResortDivider(Text(L10n.Control.lastResort))
            EmergencyButton(Text(L10n.Control.emergency), detail: Text(L10n.Control.emergencyDetail),
              symbol: Self.emergencySymbol, tag: tag) {
              chosen = { severe = .emergency }
              isPresented = false
            }
          }
        }
        Button(role: .cancel) { isPresented = false } label: {
          Text(L10n.Common.cancel)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.action(.ghost, size: .large))
        .accessibilityIdentifier(AccessibilityID.botControlCancel)
      }
      .padding(Tokens.Space.l)
    }
    .scrollEdgeHints()
    .background(Palette.background)
  }

  /// One action across the sheet, in its tier; it runs once the sheet has closed.
  private func action(
    _ title: LocalizedStringResource, symbol: String, tier: CommandButtonStyle.Tier, _ perform: @escaping () -> Void
  ) -> some View {
    Button(role: tier == .destructive ? .destructive : nil) {
      chosen = perform
      isPresented = false
    } label: {
      Label { Text(title) } icon: { Image(systemName: symbol) }
    }
    .buttonStyle(.command(tier, tag: tag))
    // One row: as tall as its title needs (it wraps at large text sizes, never cut).
    .fixedSize(horizontal: false, vertical: true)
  }

  /// The "DEMO" pill on every command while commands go to the demo day.
  private var tag: Text? { model.connection.demo ? Text(L10n.Control.demoTag) : nil }

  /// Corner radius of the sheet, in points (the design's bottom sheet).
  static let sheetRadius: CGFloat = 28

  /// Symbols of the actions and of the bot's state (Pause draws `Symbols.pause`).
  static let resumeSymbol = "play.fill"
  static let cancelSymbol = "xmark.circle"
  static let flattenSymbol = "rectangle.portrait.and.arrow.right"
  static let stopSymbol = "stop.circle"
  static let emergencySymbol = "exclamationmark.octagon.fill"
  static let unknownSymbol = "questionmark"
  static let stoppedSymbol = "stop.fill"

  private var stateSymbol: String {
    guard let status = model.status else { return Self.unknownSymbol }
    if status.entryStop { return Symbols.pause }
    return status.botState == .running ? Self.resumeSymbol : Self.stoppedSymbol
  }

  private var stateTone: Tone {
    guard let status = model.status else { return .neutral }
    if status.entryStop { return .warning }
    return status.botState == .running ? .accent : .neutral
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

  /// A confirmation's message with where the command goes, named every time: a demo switch left
  /// on must never swallow a real command unnoticed.
  static func target(_ message: String, demo: Bool) -> LocalizedStringResource {
    demo ? L10n.Control.toDemo(message) : L10n.Control.toBot(message)
  }

  private func severeMessage(_ command: OperatorCommand) -> LocalizedStringResource {
    command == .emergency ? L10n.Control.emergencyWarning : L10n.Control.stopWarning
  }

  private func run(_ command: OperatorCommand) {
    Task { await Self.confirmAndSend(command, model: model) }
  }

  /// Face ID for anything that cancels, closes, stops or lets the bot trade again; only pausing
  /// entries is safe without it. The model checks freshness before and after Face ID.
  static func confirmAndSend(_ command: OperatorCommand, model: AppModel) async {
    let reason = String(localized: L10n.Control.reason(Board.commandTitle(command.kind)))
    if needsOwner(command) {
      await model.send(command, confirmOwner: { await Biometrics.confirm(reason) })
    } else {
      await model.send(command)
    }
  }

  /// Whether `command` needs the owner's Face ID or passcode: all but pausing entries. Resuming
  /// entries lets the bot open trades again, so an unlocked phone alone is not enough for it.
  static func needsOwner(_ command: OperatorCommand) -> Bool {
    switch command {
    case .entryStop(let on): return !on
    case .cancelOwnOrders, .flatten, .flattenSymbol, .stopBot, .emergency: return true
    }
  }
}

extension View {
  func botControl(isPresented: Binding<Bool>) -> some View {
    modifier(BotControl(isPresented: isPresented))
  }
}
