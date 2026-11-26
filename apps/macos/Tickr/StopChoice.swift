import SwiftUI
import TickrDesign
import TickrKit

/// Stop bot with open positions on the Mac (backlog V4 variant A; boards Main, MainNarrow): the
/// words of its three-button alert, the close-and-stop steps in place of the Bot card's buttons,
/// and Start bot beside them and on the stopped-with-positions panel.
enum StopChoice {
  /// Accessibility ids of the alert's two answers, for the UI tests.
  static let closeAndStopID = "stop-close-and-stop"
  static let leaveOpenID = "stop-leave-open"

  /// The alert's title: "Stop the bot with 2 positions open?".
  static func title(_ stop: StopQuestion) -> String {
    guard case .choose(let symbols) = stop else { return String(localized: L10n.Bot.stopQuestion) }
    return String(localized: StopText.chooseTitle(symbols.count))
  }

  /// The alert's message: what each answer does, one paragraph each.
  static func explanation(_ stop: StopQuestion) -> String {
    guard case .choose(let symbols) = stop else { return BotAction.stopBot.explanation }
    return [String(localized: StopText.closeAndStopDetail(symbols.formatted(.list(type: .and)))),
      String(localized: StopText.leaveOpenDetail)].joined(separator: Format.lineSeparator + Format.lineSeparator)
  }
}

extension AppModel {
  /// The close-and-stop's steps while the status shows one (`StopWatch.steps`); nil otherwise.
  var stopSteps: [StopStepRow]? { stopWatch.steps(status) }

  /// Why the followed close-and-stop was refused, once the bot recorded it so.
  var stopRefusal: String? { stopWatch.refusal(status) }

  /// The bot stopped with positions open: the panel in place of the position view.
  var stoppedPositions: StoppedPositions? { StoppedPositions.make(status) }
}

/// The Bot card's foot during a close-and-stop: the four steps in place of Pause and Stop, and
/// once the bot stopped, Start bot.
struct StopStepsSection: View {
  @Environment(AppModel.self) private var model
  let rows: [StopStepRow]

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      StopStepsList(rows, event: model.status?.writtenAt)
      if rows.last?.phase == .done {
        OverviewStartButton()
      }
    }
  }
}

/// Start bot on Overview: the existing start (`AppModel.startBot`, launchd, preflight first),
/// asking first with the same words as Settings.
struct OverviewStartButton: View {
  @Environment(AppModel.self) private var model
  @State private var asking = false

  /// Accessibility id of the button, for the UI tests.
  static let id = "start-bot"

  var body: some View {
    Button { asking = true } label: {
      Label { Text(L10n.Settings.startBotAction) } icon: { Image(systemName: BotAction.resumeSymbol) }
    }
    .buttonStyle(.command(.secondary(.accent), size: .regular))
    .disabled(!model.canStartBot)
    .inFlight(model.botStarting ? Text(InFlightText.startBot) : nil)
    .hint(L10n.Settings.startBotHint)
    .accessibilityIdentifier(Self.id)
    .alert(Text(L10n.Settings.startQuestion), isPresented: $asking) {
      Button { Task { await model.startBot() } } label: { Text(L10n.Settings.startBotAction) }
      Button(String(localized: L10n.Common.cancel), role: .cancel) {}
    } message: {
      Text(L10n.Settings.startExplanation)
    }
    .onChange(of: model.canStartBot) { _, enabled in
      if !enabled { asking = false }
    }
  }
}
