import SwiftUI
import TickrDesign
import TickrKit

// Stop bot with open positions on the iPhone (backlog V4 variant A; board IOSHome): the choice
// in the bot-control sheet, the close-and-stop steps in it, and Start bot on Home's
// stopped-with-positions card.

extension AppModel {
  /// The close-and-stop's steps while the status shows one (`StopWatch.steps`); nil otherwise.
  var stopSteps: [StopStepRow]? { stopWatch.steps(status) }

  /// Why the followed close-and-stop was refused, once the bot recorded it so.
  var stopRefusal: String? { stopWatch.refusal(status) }

  /// The bot stopped with positions open: Home's card in place of the position rows.
  var stoppedPositions: StoppedPositions? { StoppedPositions.make(status) }
}

/// The sheet's question when Stop bot is pressed with positions open: what happens to them, the
/// two answers with what each does, and Cancel. Each answer asks for Face ID before it sends.
struct StopChoicePane: View {
  let symbols: [String]
  /// The "DEMO" pill while commands go to the demo day.
  let tag: Text?
  /// Commands are on (a current status); the answers are off otherwise.
  let enabled: Bool
  /// Close and stop is on its way.
  let closing: Bool
  let closeAndStop: () -> Void
  let leaveOpen: () -> Void
  let cancel: () -> Void

  /// SF Symbols of the two answers.
  static let closeSymbol = "rectangle.portrait.and.arrow.right"
  static let leaveSymbol = "stop.circle"

  var body: some View {
    let list = symbols.formatted(.list(type: .and))
    VStack(spacing: Tokens.Space.m) {
      Text(StopText.chooseTitle(symbols.count))
        .font(Tokens.Typography.headline)
        .foregroundStyle(Palette.textPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      Text(StopText.chooseBody(list))
        .font(Tokens.Typography.subheadline)
        .foregroundStyle(Palette.textTertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      answer(StopText.closeAndStop, detail: StopText.closeAndStopDetail(list), symbol: Self.closeSymbol,
        tier: .destructive, id: AccessibilityID.stopCloseAndStop, perform: closeAndStop)
        .inFlight(closing ? Text(OperatorCommand.stopBotMode(.closeAndStop).inFlightTitle) : nil)
      answer(StopText.leaveOpen, detail: StopText.leaveOpenDetail, symbol: Self.leaveSymbol,
        tier: .secondary(.warning), id: AccessibilityID.stopLeaveOpen, perform: leaveOpen)
      Button(role: .cancel, action: cancel) {
        Text(L10n.Common.cancel)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.action(.ghost, size: .large))
      .accessibilityIdentifier(AccessibilityID.botControlCancel)
    }
  }

  private func answer(
    _ title: LocalizedStringResource, detail: LocalizedStringResource, symbol: String, tier: CommandButtonStyle.Tier,
    id: String, perform: @escaping () -> Void
  ) -> some View {
    Button(role: tier == .destructive ? .destructive : nil, action: perform) {
      Label { Text(title) } icon: { Image(systemName: symbol) }
    }
    .buttonStyle(.command(tier, detail: Text(detail), tag: tag))
    // As tall as its words need (they wrap at large text sizes, never cut).
    .fixedSize(horizontal: false, vertical: true)
    .disabled(!enabled || closing)
    .accessibilityIdentifier(id)
  }
}

/// The sheet during a close-and-stop: its steps as the bot reports them, Start bot once the bot
/// stopped, and Done (the close goes on in the bot whatever the app does).
struct StopStepsPane: View {
  @Environment(AppModel.self) private var model
  let rows: [StopStepRow]
  let done: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      Text(StopText.closeAndStop)
        .font(Tokens.Typography.headline)
        .foregroundStyle(Palette.textPrimary)
      StopStepsList(rows, event: model.status?.writtenAt)
      if rows.last?.phase == .done {
        HomeStartButton()
      }
      Button(action: done) {
        Text(L10n.Control.done)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.action(.ghost, size: .large))
      .accessibilityIdentifier(AccessibilityID.botControlCancel)
    }
  }
}

/// Start bot (the existing start: the Mac's launchd, preflight first), asking first and then
/// for Face ID, as in Settings.
struct HomeStartButton: View {
  @Environment(AppModel.self) private var model
  @State private var asking = false

  var body: some View {
    Button { asking = true } label: {
      Label { Text(L10n.Control.startBot) } icon: { Image(systemName: BotControl.resumeSymbol) }
    }
    .buttonStyle(.command(.primary, tag: model.connection.demo ? Text(L10n.Control.demoTag) : nil))
    .fixedSize(horizontal: false, vertical: true)
    .disabled(!model.canStartBot)
    .inFlight(model.botStarting ? Text(InFlightText.startBot) : nil)
    .alert(Text(L10n.Control.startTitle), isPresented: $asking) {
      Button {
        Task {
          let reason = String(localized: L10n.Control.reason(String(localized: L10n.Control.startBot)))
          await model.startBot(confirmOwner: { await Biometrics.confirm(reason) })
        }
      } label: {
        Text(L10n.Control.startBot)
      }
      Button(role: .cancel) {} label: { Text(L10n.Common.cancel) }
    } message: {
      Text(L10n.Control.startWarning)
    }
    .onChange(of: model.canStartBot) { _, enabled in
      if !enabled { asking = false }
    }
  }
}
